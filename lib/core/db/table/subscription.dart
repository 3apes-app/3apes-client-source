import 'package:drift/drift.dart';

class Subscription extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  TextColumn get url => text()();

  TextColumn get ageSecretKey => text().nullable()();

  TextColumn get agePublicKey => text().nullable()();
  BoolColumn get hwidEnabled => boolean().withDefault(const Constant(false))();
  TextColumn get hwid => text().nullable()();

  DateTimeColumn get timestamp => dateTime()();

  IntColumn get uploadBytes => integer().nullable()();
  IntColumn get downloadBytes => integer().nullable()();
  IntColumn get totalBytes => integer().nullable()();
  IntColumn get expireTimestamp => integer().nullable()();
  DateTimeColumn get userInfoUpdatedAt => dateTime().nullable()();

  // 3 APES: provider headers (schema 7).
  TextColumn get providerTitle => text().nullable()();
  TextColumn get announce => text().nullable()();
  TextColumn get supportUrl => text().nullable()();
  TextColumn get webPageUrl => text().nullable()();
  IntColumn get updateIntervalHours => integer().nullable()();

  // 3 APES: reserve address from the fallback-url header (schema 8).
  TextColumn get fallbackUrl => text().nullable()();
}
