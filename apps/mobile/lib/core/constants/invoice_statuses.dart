/// Full invoice lifecycle states.
class InvoiceStatuses {
  InvoiceStatuses._();

  static const draft = 'draft';
  static const sent = 'sent';
  static const viewed = 'viewed';
  static const partial = 'partial';
  static const paid = 'paid';
  static const overdue = 'overdue';
  static const disputed = 'disputed';
  static const canceled = 'canceled';

  static const all = [draft, sent, viewed, partial, paid, overdue, disputed, canceled];

  static const outstanding = [sent, viewed, partial, overdue];

  static String label(String status) {
    return status.split('_').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
  }

  static bool isEditable(String status) => status == draft || status == sent;

  static bool canClientPay(String status) =>
      status == sent || status == viewed || status == partial || status == overdue;
}
