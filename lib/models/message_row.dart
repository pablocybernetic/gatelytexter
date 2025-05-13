class MessageRow {
  MessageRow({
    required this.numbers,
    required this.body,
    this.status = '', // ← NEW
  });

  List<String> numbers;
  String body;
  String status; // “Sent”, “Skipped”, “Invalid”…

  // convenience for csv_loader
  factory MessageRow.fromCsv(List<String> cols) =>
      MessageRow(numbers: cols[0].split(';'), body: cols[1]);
}
