import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/app_routes.dart';

/// "Search citizen by ID number" in the top-right of every department
/// official's header -- an inline field on wide layouts, a search icon on
/// narrow ones. Either way it opens [DepartmentCitizenSearchScreen], with
/// the typed ID (if any) passed as `?id=` and searched immediately.
class DepartmentHeaderSearch extends StatefulWidget {
  const DepartmentHeaderSearch({super.key});

  static const _inlineBreakpoint = 600.0;

  @override
  State<DepartmentHeaderSearch> createState() => _DepartmentHeaderSearchState();
}

class _DepartmentHeaderSearchState extends State<DepartmentHeaderSearch> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openSearch([String? idNumber]) {
    final id = idNumber?.trim() ?? '';
    final location = id.isEmpty
        ? AppRoutes.departmentCitizenSearch
        : Uri(path: AppRoutes.departmentCitizenSearch, queryParameters: {'id': id}).toString();
    _controller.clear();
    context.push(location);
  }

  @override
  Widget build(BuildContext context) {
    final isInline = MediaQuery.sizeOf(context).width >= DepartmentHeaderSearch._inlineBreakpoint;

    if (!isInline) {
      return IconButton(
        icon: const Icon(Icons.person_search_outlined),
        tooltip: 'Search citizen by ID number',
        onPressed: _openSearch,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: SizedBox(
        width: 300,
        height: 40,
        child: TextField(
          controller: _controller,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.search,
          onSubmitted: _openSearch,
          decoration: InputDecoration(
            hintText: 'Search citizen by ID number',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            prefixIcon: const Icon(Icons.person_search_outlined, size: 20),
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
