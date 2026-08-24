abstract base class const Pagination();

final class const OffsetLimitPagination({
  required final int offset,
  required final int limit,
}) extends Pagination;
