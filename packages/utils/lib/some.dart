/// A wrapper class to represent an optional value that can be set to null explicitly.
///
/// Useful for copyWith methods where you want to distinguish between "not set" and "set to null".
class Some<T> {
  final T value;
  const Some(this.value);
}
