import 'package:apexo/services/localization/locale.dart';
import 'package:fluent_ui/fluent_ui.dart';

class TagInputItem extends AutoSuggestBoxItem<String> {
  TagInputItem({required super.value, required super.label});
}

class TagInputWidget extends StatefulWidget {
  final List<TagInputItem> suggestions;
  final List<TagInputItem> initialValue;
  final bool strict;
  final int limit;
  final void Function(List<TagInputItem>) onChanged;
  final void Function(TagInputItem)? onItemTap;
  final String placeholder;
  final TextEditingController? controller; // <-- Add this
  final FocusNode? focusNode; // <-- Add this
  final bool clearButton; // <-- Add this

  const TagInputWidget({
    super.key,
    required this.suggestions,
    required this.onChanged,
    required this.initialValue,
    required this.strict,
    required this.limit,
    this.placeholder = "",
    this.onItemTap,
    this.controller,
    this.focusNode,
    this.clearButton = false, // <-- Add this
  });

  @override
  TagInputWidgetState createState() => TagInputWidgetState();
}

class TagInputWidgetState extends State<TagInputWidget> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late List<TagInputItem> _tags;
  late List<TagInputItem> _filteredSuggestions;
  final key = GlobalKey<AutoSuggestBoxState>();

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _focusNode = widget.focusNode ?? FocusNode();
    _filteredSuggestions = widget.suggestions;
    _tags = List<TagInputItem>.from(widget.initialValue, growable: true);
  }

  @override
  void didUpdateWidget(covariant TagInputWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldValues = oldWidget.initialValue
        .map((e) => '${e.value}|${e.label}')
        .toList(growable: false);
    final newValues = widget.initialValue
        .map((e) => '${e.value}|${e.label}')
        .toList(growable: false);

    if (oldValues.join('||') != newValues.join('||')) {
      _tags = List<TagInputItem>.from(widget.initialValue, growable: true);
    }

    _filteredSuggestions = widget.suggestions;
  }

  void _onTextChanged(String inputVal, _) {
    // this CAN be triggered while the widget has been unmounted/rebuilt
    // that's why we're keeping the "mounted" condition
    if (!mounted) return;

    setState(() {
      if (inputVal.isEmpty) {
        _filteredSuggestions = widget.suggestions;
      } else {
        _filteredSuggestions = widget.suggestions
            .where((suggestion) =>
                _tags
                    .map((e) => e.label.toLowerCase())
                    .contains(suggestion.label.toLowerCase()) ==
                false)
            .toList();

        // Always add the current input value to the suggestions
        if (widget.strict == false &&
            _filteredSuggestions.map((e) => e.label).contains(inputVal) ==
                false) {
          _filteredSuggestions.insert(
              0,
              TagInputItem(
                  value: inputVal.replaceAll(" ", "-"), label: inputVal));
        }
      }
    });

    // Refresh the AutoSuggestBox suggestions by slightly altering the input value
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_controller.text.isNotEmpty) {
        final currentPosition = _controller.selection;
        _controller.text = _controller.text;
        _controller.selection = currentPosition;
        _focusNode.requestFocus();
      }
    });
  }

  void _onSuggestionSelected(AutoSuggestBoxItem<String> suggestion) {
    setState(() {
      _tags.add(TagInputItem(value: suggestion.value, label: suggestion.label));
      _controller.clear();
      _filteredSuggestions = widget.suggestions;
    });

    // Force the text field to clear by updating the text field directly
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.text = '';
      _onTextChanged('', null); // Refresh suggestions
    });

    widget.onChanged(_tags);
  }

  void _removeTag(TagInputItem tag) {
    setState(() {
      _tags.removeWhere((e) => e.value == tag.value);
    });
    widget.onChanged(_tags);
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: _tags.isEmpty
            ? null
            : Border.all(color: const Color.fromARGB(255, 221, 221, 221)),
        borderRadius: _tags.isEmpty ? null : BorderRadius.circular(4),
        color: _tags.isEmpty ? null : FluentTheme.of(context).menuColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(_tags.isEmpty ? 0 : 3),
            child: Wrap(
              spacing: 3,
              runSpacing: 3,
              children: _tags.map((tag) {
                return _buildTag(tag);
              }).toList(),
            ),
          ),
          if (widget.limit > _tags.length)
            Stack(
              alignment: Alignment.centerRight,
              children: [
                AutoSuggestBox<String>(
                  key: key,
                  controller: _controller,
                  focusNode: _focusNode,
                  textInputAction: TextInputAction.none,
                  decoration: WidgetStateProperty.all(BoxDecoration(
                    border: Border.all(
                        color: const Color.fromARGB(255, 220, 220, 220),
                        width: _tags.isEmpty ? 1.25 : 0.01),
                  )),
                  items: _filteredSuggestions
                      .where((suggestion) => _tags
                          .where(
                              (selected) => selected.value == suggestion.value)
                          .isEmpty)
                      .toList(),
                  onSelected: _onSuggestionSelected,
                  onChanged: _onTextChanged,
                  placeholder: widget.placeholder,
                  noResultsFoundBuilder: (context) => Padding(
                      padding: const EdgeInsets.all(10),
                      child: Txt(txt("noResultsFound"))),
                  trailingIcon: GestureDetector(
                    child: const Icon(FluentIcons.grouped_descending),
                    onTap: () {
                      if (key.currentState != null) {
                        var state = key.currentState!;
                        if (state.isOverlayVisible) {
                          state.dismissOverlay();
                          _focusNode.unfocus();
                        } else {
                          state.showOverlay();
                          _focusNode.requestFocus();
                        }
                      }
                    },
                  ),
                ),
                if (widget.clearButton && _controller.text.isNotEmpty)
                  Positioned(
                    right: 4,
                    child: IconButton(
                      icon: const Icon(FluentIcons.cancel, size: 18),
                      onPressed: () {
                        setState(() {
                          _controller.clear();
                          // Optionally, trigger suggestions overlay
                          _focusNode.requestFocus();
                        });
                      },
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Color _chipBackground(String label) {
    const palette = [
      Color(0xFFE8F1FF),
      Color(0xFFEAF9F4),
      Color(0xFFFFF3E8),
      Color(0xFFF2EEFF),
      Color(0xFFFFEAF1),
      Color(0xFFE9F7FF),
      Color(0xFFF2F8E9),
      Color(0xFFFFF7E6),
    ];
    return palette[label.hashCode.abs() % palette.length];
  }

  Color _chipBorder(String label) {
    const palette = [
      Color(0xFF8FB7EE),
      Color(0xFF95D3B7),
      Color(0xFFE7BC8F),
      Color(0xFFB7A6E8),
      Color(0xFFE59AB9),
      Color(0xFF9FD0E8),
      Color(0xFFBFD8A0),
      Color(0xFFE8CC8F),
    ];
    return palette[label.hashCode.abs() % palette.length];
  }

  Padding _buildTag(TagInputItem tag) {
    final chipBg = _chipBackground(tag.label);
    final chipBorder = _chipBorder(tag.label);
    return Padding(
      padding: const EdgeInsets.only(right: 2, bottom: 2),
      child: Acrylic(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        elevation: 1,
        tint: chipBg,
        child: IconButton(
          onPressed: () =>
              widget.onItemTap == null ? null : widget.onItemTap!(tag),
          style: const ButtonStyle(
            padding: WidgetStatePropertyAll(
                EdgeInsets.only(left: 10, right: 5, top: 5, bottom: 5)),
          ),
          icon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: chipBorder),
                ),
                child: Txt(tag.label),
              ),
              const SizedBox(width: 5),
              IconButton(
                key: Key("${tag.label}_clear"),
                icon: const Icon(FluentIcons.clear, size: 10),
                onPressed: () => _removeTag(tag),
                style: ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(
                        Colors.black.withValues(alpha: 0.05))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
