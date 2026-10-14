import 'package:drift/drift.dart';

class Leagues extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get country => text()();
  IntColumn get tier => integer()();
  IntColumn get strength => integer()();
}

class Clubs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get leagueId => integer().references(Leagues, #id)();
  IntColumn get reputation => integer()();
  IntColumn get budget => integer().withDefault(const Constant(0))();
  IntColumn get stadiumLevel => integer().withDefault(const Constant(1))();
  IntColumn get trainingLevel => integer().withDefault(const Constant(1))();
}

class Players extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get fullName => text()();
  IntColumn get age => integer()();
  TextColumn get nationality => text()();
  IntColumn get clubId => integer().nullable().references(Clubs, #id)();
  TextColumn get positions => text()(); // CSV, first = primary
  TextColumn get preferredFoot => text()();
  IntColumn get overall => integer()();
  IntColumn get potential => integer()();
  IntColumn get pace => integer().withDefault(const Constant(50))();
  IntColumn get acceleration => integer().withDefault(const Constant(50))();
  IntColumn get shooting => integer().withDefault(const Constant(50))();
  IntColumn get finishing => integer().withDefault(const Constant(50))();
  IntColumn get passing => integer().withDefault(const Constant(50))();
  IntColumn get crossing => integer().withDefault(const Constant(50))();
  IntColumn get dribbling => integer().withDefault(const Constant(50))();
  IntColumn get technique => integer().withDefault(const Constant(50))();
  IntColumn get defending => integer().withDefault(const Constant(50))();
  IntColumn get tackling => integer().withDefault(const Constant(50))();
  IntColumn get physical => integer().withDefault(const Constant(50))();
  IntColumn get strength => integer().withDefault(const Constant(50))();
  IntColumn get stamina => integer().withDefault(const Constant(50))();
  IntColumn get jumping => integer().withDefault(const Constant(50))();
  IntColumn get decisionMaking => integer().withDefault(const Constant(50))();
  IntColumn get workRate => integer().withDefault(const Constant(50))();
  IntColumn get vision => integer().withDefault(const Constant(50))();
  IntColumn get composure => integer().withDefault(const Constant(50))();
  IntColumn get handling => integer().withDefault(const Constant(10))();
  IntColumn get reflexes => integer().withDefault(const Constant(10))();
  IntColumn get positioning => integer().withDefault(const Constant(10))();
  IntColumn get kicking => integer().withDefault(const Constant(10))();
  IntColumn get command => integer().withDefault(const Constant(10))();
  IntColumn get form => integer().withDefault(const Constant(60))();
  IntColumn get fitness => integer().withDefault(const Constant(100))();
  IntColumn get morale => integer().withDefault(const Constant(70))();
  IntColumn get injuryProneness => integer().withDefault(const Constant(10))();
  IntColumn get contractEndYear => integer()();
  IntColumn get wagePerWeek => integer()();
  IntColumn get value => integer()();
}

class Seasons extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get year => integer()();
  IntColumn get currentDay => integer().withDefault(const Constant(0))();
}

class CareerSaves extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get clubId => integer().nullable().references(Clubs, #id)();
  IntColumn get seasonId => integer().references(Seasons, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get formation => text().withDefault(const Constant('4-3-3'))();
  IntColumn get mentality => integer().withDefault(const Constant(2))();
  IntColumn get verticality => integer().withDefault(const Constant(1))();
}

class Fixtures extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get seasonId => integer().references(Seasons, #id)();
  TextColumn get competition => text()();
  IntColumn get round => integer()();
  IntColumn get day => integer()();
  IntColumn get homeClubId => integer().references(Clubs, #id)();
  IntColumn get awayClubId => integer().references(Clubs, #id)();
  BoolColumn get played => boolean().withDefault(const Constant(false))();
}

class MatchResults extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get fixtureId => integer().references(Fixtures, #id)();
  IntColumn get homeGoals => integer()();
  IntColumn get awayGoals => integer()();
  TextColumn get eventsJson => text().withDefault(const Constant('[]'))();
}

class Transfers extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get playerId => integer().references(Players, #id)();
  IntColumn get fromClubId => integer().nullable().references(Clubs, #id)();
  IntColumn get toClubId => integer().references(Clubs, #id)();
  IntColumn get fee => integer()();
  IntColumn get seasonId => integer().references(Seasons, #id)();
  IntColumn get day => integer()();
}

class Loans extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get playerId => integer().references(Players, #id)();
  IntColumn get fromClubId => integer().references(Clubs, #id)();
  IntColumn get toClubId => integer().references(Clubs, #id)();
  IntColumn get fee => integer().withDefault(const Constant(0))();
  IntColumn get wageSplitPct => integer().withDefault(const Constant(50))();
  IntColumn get seasonId => integer().references(Seasons, #id)();
}

class TrainingSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get clubId => integer().references(Clubs, #id)();
  IntColumn get seasonId => integer().references(Seasons, #id)();
  IntColumn get week => integer()();
  TextColumn get focus => text()();
}

class FinanceEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get seasonId => integer().references(Seasons, #id)();
  IntColumn get clubId => integer().references(Clubs, #id)();
  IntColumn get day => integer()();
  TextColumn get kind => text()(); // tickets, commercial, wages, transfer_in, transfer_out
  IntColumn get amount => integer()(); // + income, - expense
  TextColumn get note => text().withDefault(const Constant(''))();
}
