import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A search field in the middle of a role's header -- an inline field on
/// wide layouts, a search icon beside Profile on narrow ones. Either way it
/// opens [searchRoute] (that role's own search screen), with the typed text
/// (if any) passed as `?[queryParameter]=` and searched immediately.
///
/// Department officials use it to search citizens by ID number; the
/// administrator's version searches every actor on UbuntuID.
class HeaderSearch extends StatefulWidget {
  const HeaderSearch({
    super.key,
    required this.searchRoute,
    required this.hintText,
    required this.queryParameter,
    this.icon = Icons.search,
    this.keyboardType,
  });

  final String searchRoute;
  final String hintText;
  final String queryParameter;
  final IconData icon;
  final TextInputType? keyboardType;

  static const _inlineBreakpoint = 600.0;

  @override
  State<HeaderSearch> createState() => _HeaderSearchState();
}

class _HeaderSearchState extends State<HeaderSearch> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openSearch([String? text]) {
    final query = text?.trim() ?? '';
    final location = query.isEmpty
        ? widget.searchRoute
        : Uri(path: widget.searchRoute, queryParameters: {widget.queryParameter: query}).toString();
    _controller.clear();
    context.push(location);
  }

  @override
  Widget build(BuildContext context) {
    final isInline = MediaQuery.sizeOf(context).width >= HeaderSearch._inlineBreakpoint;

    if (!isInline) {
      return IconButton(
        icon: Icon(widget.icon),
        tooltip: widget.hintText,
        onPressed: _openSearch,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SizedBox(
        width: 340,
        height: 40,
        child: TextField(
          controller: _controller,
          keyboardType: widget.keyboardType,
          textInputAction: TextInputAction.search,
          onSubmitted: _openSearch,
          decoration: InputDecoration(
            hintText: widget.hintText,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            prefixIcon: Icon(widget.icon, size: 20),
            suffixIcon: IconButton(
              icon: const Icon(Icons.arrow_forward, size: 18),
              tooltip: 'Search',
              onPressed: () => _openSearch(_controller.text),
            ),
          ),
        ),
      ),
    );
  }
}
