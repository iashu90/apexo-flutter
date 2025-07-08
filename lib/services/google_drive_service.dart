import 'dart:convert';
import 'dart:io';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart';
import 'package:flutter/material.dart' as material;
import 'package:url_launcher/url_launcher.dart';

class GoogleDriveService {
  final String identifier;
  final String secret;
  final List<String> scopes;

  GoogleDriveService({
    required this.identifier,
    required this.secret,
    required this.scopes,
  });

  ClientId get clientId => ClientId(identifier, secret);

  Future<AuthClient?> getSavedAuthClient() async {
    final box = await Hive.openBox('settings');
    final credsJson = box.get('googleDriveCredentials');
    if (credsJson == null) return null;
    try {
      final credentials = AccessCredentials.fromJson(json.decode(credsJson));
      return authenticatedClient(Client(), credentials);
    } catch (e) {
      print('Failed to load saved credentials: $e');
      return null;
    }
  }

  Future<String?> showGoogleAuthDialog(
      material.BuildContext context, Uri authUri) async {
    final controller = material.TextEditingController();
    return await material.showDialog<String>(
      context: context,
      builder: (context) => material.AlertDialog(
        backgroundColor: material.Colors.white,
        title: const material.Text('Google Drive Authentication'),
        content: material.Column(
          mainAxisSize: material.MainAxisSize.min,
          crossAxisAlignment: material.CrossAxisAlignment.start,
          children: [
            const material.Text('1. Click the link below and grant access:'),
            material.SelectableText(
              authUri.toString(),
              style: const material.TextStyle(color: material.Colors.blue),
              onTap: () async {
                if (await canLaunchUrl(authUri)) {
                  await launchUrl(authUri);
                }
              },
            ),
            const material.SizedBox(height: 16),
            const material.Text('2. Paste the code you receive here:'),
            material.TextField(
              controller: controller,
              decoration: const material.InputDecoration(
                labelText: 'Enter code',
              ),
            ),
          ],
        ),
        actions: [
          material.TextButton(
            onPressed: () =>
                material.Navigator.of(context).pop(controller.text.trim()),
            child: const material.Text('Submit'),
          ),
          material.TextButton(
            onPressed: () => material.Navigator.of(context).pop(),
            child: const material.Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<AuthClient> getUserConsentAuthClient(
      material.BuildContext context) async {
    var authUri = Uri.https('accounts.google.com', '/o/oauth2/auth', {
      'client_id': identifier,
      'redirect_uri': 'urn:ietf:wg:oauth:2.0:oob',
      'response_type': 'code',
      'scope': scopes.join(' '),
      'access_type': 'offline',
      'prompt': 'consent',
    });

    final code = await showGoogleAuthDialog(context, authUri);
    if (code == null || code.isEmpty) {
      throw Exception('Authentication cancelled by user.');
    }

    final client = Client();
    final response = await client.post(
      Uri.parse('https://oauth2.googleapis.com/token'),
      body: {
        'code': code,
        'client_id': identifier,
        'client_secret': secret,
        'redirect_uri': 'urn:ietf:wg:oauth:2.0:oob',
        'grant_type': 'authorization_code',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to obtain credentials: ${response.body}');
    }

    final decoded = json.decode(response.body);
    if (decoded == null || decoded is! Map<String, dynamic>) {
      throw Exception(
          'Failed to obtain credentials: Invalid response: ${response.body}');
    }

    final accessToken = AccessToken(
      decoded['token_type'] as String,
      decoded['access_token'] as String,
      DateTime.now()
          .add(Duration(seconds: decoded['expires_in'] as int))
          .toUtc(),
    );

    final credentials = AccessCredentials(
      accessToken,
      decoded['refresh_token'] as String?,
      scopes,
    );

    final box = await Hive.openBox('settings');
    await box.put('googleDriveCredentials', json.encode(credentials.toJson()));
    return authenticatedClient(client, credentials);
  }

  Future<String> getOrCreateDriveFolder(
      drive.DriveApi driveApi, String folderName) async {
    final query =
        "mimeType = 'application/vnd.google-apps.folder' and name = '$folderName' and trashed = false";
    final folders =
        await driveApi.files.list(q: query, $fields: "files(id, name)");
    if (folders.files != null && folders.files!.isNotEmpty) {
      return folders.files!.first.id!;
    }

    final folder = drive.File();
    folder.name = folderName;
    folder.mimeType = 'application/vnd.google-apps.folder';
    final created = await driveApi.files.create(folder);
    return created.id!;
  }

  Future<void> uploadFileToDrive({
    required AuthClient client,
    required File file,
    required String folderName,
    String? fileName,
    void Function()? onSuccess,
  }) async {
    final driveApi = drive.DriveApi(client);
    final folderId = await getOrCreateDriveFolder(driveApi, folderName);

    final driveFile = drive.File();
    driveFile.name = fileName ?? file.path.split('/').last;
    driveFile.parents = [folderId];
    final media = drive.Media(file.openRead(), await file.length());

    final uploadedFile = await driveApi.files.create(
      driveFile,
      uploadMedia: media,
    );

    print('Uploaded file ID: ${uploadedFile.id}');
    if (onSuccess != null) onSuccess();
  }
}
