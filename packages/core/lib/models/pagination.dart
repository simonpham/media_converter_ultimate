abstract base class Pagination {
  const Pagination();
}

final class OffsetLimitPagination extends Pagination {
  final int offset;
  final int limit;

  const OffsetLimitPagination({
    required this.offset,
    required this.limit,
  });
}
