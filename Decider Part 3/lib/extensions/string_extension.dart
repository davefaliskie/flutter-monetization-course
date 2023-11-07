extension StringExtension on String {
  String capitalize() {
    if (this == "") {
      return this;
    } else {
      return "${this[0].toUpperCase()}${this.substring(1).toLowerCase()}";
    }
  }
}