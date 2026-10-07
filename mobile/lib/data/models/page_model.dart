/// One page of a paginated list: backend shape {"items", "page", "limit", "total"}.
class PageModel<T> {
  final List<T> items;
  final int page;
  final int limit;
  final int total;

  const PageModel({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
  });

  bool get hasMore => page * limit < total;

  factory PageModel.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> item) parseItem,
  ) {
    final items = (json['items'] as List<dynamic>? ?? const [])
        .map((e) => parseItem(e as Map<String, dynamic>))
        .toList();
    return PageModel(
      items: items,
      page: json['page'] as int? ?? 1,
      limit: json['limit'] as int? ?? items.length,
      total: json['total'] as int? ?? items.length,
    );
  }
}
