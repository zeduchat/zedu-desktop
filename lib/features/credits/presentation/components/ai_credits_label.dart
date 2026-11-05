/// "1 AI credit", "25 AI credits": the balance label used in Billing and the
/// user menu.
String aiCreditsLabel(int count) =>
    count == 1 ? '1 AI credit' : '$count AI credits';
