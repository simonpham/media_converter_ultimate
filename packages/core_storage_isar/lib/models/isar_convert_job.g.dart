// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'isar_convert_job.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetIsarConvertJobCollection on Isar {
  IsarCollection<IsarConvertJob> get isarConvertJobs => this.collection();
}

const IsarConvertJobSchema = CollectionSchema(
  name: r'IsarConvertJob',
  id: -7484796388435112245,
  properties: {
    r'command': PropertySchema(id: 0, name: r'command', type: IsarType.string),
    r'convertedFilePath': PropertySchema(
      id: 1,
      name: r'convertedFilePath',
      type: IsarType.string,
    ),
    r'createdAt': PropertySchema(
      id: 2,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'duration': PropertySchema(id: 3, name: r'duration', type: IsarType.long),
    r'id': PropertySchema(id: 4, name: r'id', type: IsarType.string),
    r'inputFilePath': PropertySchema(
      id: 5,
      name: r'inputFilePath',
      type: IsarType.string,
    ),
    r'outputDirectoryPath': PropertySchema(
      id: 6,
      name: r'outputDirectoryPath',
      type: IsarType.string,
    ),
    r'outputExtension': PropertySchema(
      id: 7,
      name: r'outputExtension',
      type: IsarType.string,
    ),
    r'outputFileName': PropertySchema(
      id: 8,
      name: r'outputFileName',
      type: IsarType.string,
    ),
    r'progress': PropertySchema(id: 9, name: r'progress', type: IsarType.long),
    r'sessionId': PropertySchema(
      id: 10,
      name: r'sessionId',
      type: IsarType.long,
    ),
    r'status': PropertySchema(
      id: 11,
      name: r'status',
      type: IsarType.string,
      enumMap: _IsarConvertJobstatusEnumValueMap,
    ),
    r'updatedAt': PropertySchema(
      id: 12,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
  },

  estimateSize: _isarConvertJobEstimateSize,
  serialize: _isarConvertJobSerialize,
  deserialize: _isarConvertJobDeserialize,
  deserializeProp: _isarConvertJobDeserializeProp,
  idName: r'isarId',
  indexes: {
    r'createdAt': IndexSchema(
      id: -3433535483987302584,
      name: r'createdAt',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'createdAt',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
    r'updatedAt': IndexSchema(
      id: -6238191080293565125,
      name: r'updatedAt',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'updatedAt',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
    r'status': IndexSchema(
      id: -107785170620420283,
      name: r'status',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'status',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _isarConvertJobGetId,
  getLinks: _isarConvertJobGetLinks,
  attach: _isarConvertJobAttach,
  version: '3.3.2',
);

int _isarConvertJobEstimateSize(
  IsarConvertJob object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.command.length * 3;
  bytesCount += 3 + object.convertedFilePath.length * 3;
  bytesCount += 3 + object.id.length * 3;
  bytesCount += 3 + object.inputFilePath.length * 3;
  bytesCount += 3 + object.outputDirectoryPath.length * 3;
  bytesCount += 3 + object.outputExtension.length * 3;
  bytesCount += 3 + object.outputFileName.length * 3;
  bytesCount += 3 + object.status.name.length * 3;
  return bytesCount;
}

void _isarConvertJobSerialize(
  IsarConvertJob object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.command);
  writer.writeString(offsets[1], object.convertedFilePath);
  writer.writeDateTime(offsets[2], object.createdAt);
  writer.writeLong(offsets[3], object.duration);
  writer.writeString(offsets[4], object.id);
  writer.writeString(offsets[5], object.inputFilePath);
  writer.writeString(offsets[6], object.outputDirectoryPath);
  writer.writeString(offsets[7], object.outputExtension);
  writer.writeString(offsets[8], object.outputFileName);
  writer.writeLong(offsets[9], object.progress);
  writer.writeLong(offsets[10], object.sessionId);
  writer.writeString(offsets[11], object.status.name);
  writer.writeDateTime(offsets[12], object.updatedAt);
}

IsarConvertJob _isarConvertJobDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = IsarConvertJob(
    command: reader.readString(offsets[0]),
    convertedFilePath: reader.readString(offsets[1]),
    createdAt: reader.readDateTime(offsets[2]),
    duration: reader.readLongOrNull(offsets[3]),
    id: reader.readString(offsets[4]),
    inputFilePath: reader.readString(offsets[5]),
    outputDirectoryPath: reader.readString(offsets[6]),
    outputExtension: reader.readString(offsets[7]),
    outputFileName: reader.readString(offsets[8]),
    progress: reader.readLongOrNull(offsets[9]),
    sessionId: reader.readLongOrNull(offsets[10]),
    status:
        _IsarConvertJobstatusValueEnumMap[reader.readStringOrNull(
          offsets[11],
        )] ??
        JobStatus.pending,
    updatedAt: reader.readDateTime(offsets[12]),
  );
  return object;
}

P _isarConvertJobDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readDateTime(offset)) as P;
    case 3:
      return (reader.readLongOrNull(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readString(offset)) as P;
    case 9:
      return (reader.readLongOrNull(offset)) as P;
    case 10:
      return (reader.readLongOrNull(offset)) as P;
    case 11:
      return (_IsarConvertJobstatusValueEnumMap[reader.readStringOrNull(
                offset,
              )] ??
              JobStatus.pending)
          as P;
    case 12:
      return (reader.readDateTime(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _IsarConvertJobstatusEnumValueMap = {
  r'pending': r'pending',
  r'preparing': r'preparing',
  r'ready': r'ready',
  r'running': r'running',
  r'cleaning': r'cleaning',
  r'cancelled': r'cancelled',
  r'failed': r'failed',
  r'actionRequired': r'actionRequired',
  r'completed': r'completed',
};
const _IsarConvertJobstatusValueEnumMap = {
  r'pending': JobStatus.pending,
  r'preparing': JobStatus.preparing,
  r'ready': JobStatus.ready,
  r'running': JobStatus.running,
  r'cleaning': JobStatus.cleaning,
  r'cancelled': JobStatus.cancelled,
  r'failed': JobStatus.failed,
  r'actionRequired': JobStatus.actionRequired,
  r'completed': JobStatus.completed,
};

Id _isarConvertJobGetId(IsarConvertJob object) {
  return object.isarId;
}

List<IsarLinkBase<dynamic>> _isarConvertJobGetLinks(IsarConvertJob object) {
  return [];
}

void _isarConvertJobAttach(
  IsarCollection<dynamic> col,
  Id id,
  IsarConvertJob object,
) {}

extension IsarConvertJobQueryWhereSort
    on QueryBuilder<IsarConvertJob, IsarConvertJob, QWhere> {
  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterWhere> anyIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterWhere> anyCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'createdAt'),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterWhere> anyUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'updatedAt'),
      );
    });
  }
}

extension IsarConvertJobQueryWhere
    on QueryBuilder<IsarConvertJob, IsarConvertJob, QWhereClause> {
  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterWhereClause> isarIdEqualTo(
    Id isarId,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(lower: isarId, upper: isarId),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterWhereClause>
  isarIdNotEqualTo(Id isarId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: isarId, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: isarId, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: isarId, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: isarId, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterWhereClause>
  isarIdGreaterThan(Id isarId, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: isarId, includeLower: include),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterWhereClause>
  isarIdLessThan(Id isarId, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: isarId, includeUpper: include),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterWhereClause> isarIdBetween(
    Id lowerIsarId,
    Id upperIsarId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerIsarId,
          includeLower: includeLower,
          upper: upperIsarId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterWhereClause>
  createdAtEqualTo(DateTime createdAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'createdAt', value: [createdAt]),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterWhereClause>
  createdAtNotEqualTo(DateTime createdAt) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'createdAt',
                lower: [],
                upper: [createdAt],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'createdAt',
                lower: [createdAt],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'createdAt',
                lower: [createdAt],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'createdAt',
                lower: [],
                upper: [createdAt],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterWhereClause>
  createdAtGreaterThan(DateTime createdAt, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'createdAt',
          lower: [createdAt],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterWhereClause>
  createdAtLessThan(DateTime createdAt, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'createdAt',
          lower: [],
          upper: [createdAt],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterWhereClause>
  createdAtBetween(
    DateTime lowerCreatedAt,
    DateTime upperCreatedAt, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'createdAt',
          lower: [lowerCreatedAt],
          includeLower: includeLower,
          upper: [upperCreatedAt],
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterWhereClause>
  updatedAtEqualTo(DateTime updatedAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'updatedAt', value: [updatedAt]),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterWhereClause>
  updatedAtNotEqualTo(DateTime updatedAt) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'updatedAt',
                lower: [],
                upper: [updatedAt],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'updatedAt',
                lower: [updatedAt],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'updatedAt',
                lower: [updatedAt],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'updatedAt',
                lower: [],
                upper: [updatedAt],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterWhereClause>
  updatedAtGreaterThan(DateTime updatedAt, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'updatedAt',
          lower: [updatedAt],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterWhereClause>
  updatedAtLessThan(DateTime updatedAt, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'updatedAt',
          lower: [],
          upper: [updatedAt],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterWhereClause>
  updatedAtBetween(
    DateTime lowerUpdatedAt,
    DateTime upperUpdatedAt, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'updatedAt',
          lower: [lowerUpdatedAt],
          includeLower: includeLower,
          upper: [upperUpdatedAt],
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterWhereClause> statusEqualTo(
    JobStatus status,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'status', value: [status]),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterWhereClause>
  statusNotEqualTo(JobStatus status) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'status',
                lower: [],
                upper: [status],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'status',
                lower: [status],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'status',
                lower: [status],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'status',
                lower: [],
                upper: [status],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension IsarConvertJobQueryFilter
    on QueryBuilder<IsarConvertJob, IsarConvertJob, QFilterCondition> {
  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  commandEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'command',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  commandGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'command',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  commandLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'command',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  commandBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'command',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  commandStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'command',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  commandEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'command',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  commandContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'command',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  commandMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'command',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  commandIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'command', value: ''),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  commandIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'command', value: ''),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  convertedFilePathEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'convertedFilePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  convertedFilePathGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'convertedFilePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  convertedFilePathLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'convertedFilePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  convertedFilePathBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'convertedFilePath',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  convertedFilePathStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'convertedFilePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  convertedFilePathEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'convertedFilePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  convertedFilePathContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'convertedFilePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  convertedFilePathMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'convertedFilePath',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  convertedFilePathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'convertedFilePath', value: ''),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  convertedFilePathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'convertedFilePath', value: ''),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'createdAt', value: value),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  createdAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  createdAtLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'createdAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  durationIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'duration'),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  durationIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'duration'),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  durationEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'duration', value: value),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  durationGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'duration',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  durationLessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'duration',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  durationBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'duration',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition> idEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  idGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  idLessThan(String value, {bool include = false, bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition> idBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  idStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  idEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  idContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition> idMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  idIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: ''),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  idIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'id', value: ''),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  inputFilePathEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'inputFilePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  inputFilePathGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'inputFilePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  inputFilePathLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'inputFilePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  inputFilePathBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'inputFilePath',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  inputFilePathStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'inputFilePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  inputFilePathEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'inputFilePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  inputFilePathContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'inputFilePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  inputFilePathMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'inputFilePath',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  inputFilePathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'inputFilePath', value: ''),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  inputFilePathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'inputFilePath', value: ''),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  isarIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isarId', value: value),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  isarIdGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'isarId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  isarIdLessThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'isarId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  isarIdBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'isarId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  outputDirectoryPathEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'outputDirectoryPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  outputDirectoryPathGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'outputDirectoryPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  outputDirectoryPathLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'outputDirectoryPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  outputDirectoryPathBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'outputDirectoryPath',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  outputDirectoryPathStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'outputDirectoryPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  outputDirectoryPathEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'outputDirectoryPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  outputDirectoryPathContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'outputDirectoryPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  outputDirectoryPathMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'outputDirectoryPath',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  outputDirectoryPathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'outputDirectoryPath', value: ''),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  outputDirectoryPathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          property: r'outputDirectoryPath',
          value: '',
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  outputExtensionEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'outputExtension',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  outputExtensionGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'outputExtension',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  outputExtensionLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'outputExtension',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  outputExtensionBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'outputExtension',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  outputExtensionStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'outputExtension',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  outputExtensionEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'outputExtension',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  outputExtensionContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'outputExtension',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  outputExtensionMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'outputExtension',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  outputExtensionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'outputExtension', value: ''),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  outputExtensionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'outputExtension', value: ''),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  outputFileNameEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'outputFileName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  outputFileNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'outputFileName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  outputFileNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'outputFileName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  outputFileNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'outputFileName',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  outputFileNameStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'outputFileName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  outputFileNameEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'outputFileName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  outputFileNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'outputFileName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  outputFileNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'outputFileName',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  outputFileNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'outputFileName', value: ''),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  outputFileNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'outputFileName', value: ''),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  progressIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'progress'),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  progressIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'progress'),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  progressEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'progress', value: value),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  progressGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'progress',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  progressLessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'progress',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  progressBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'progress',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  sessionIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'sessionId'),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  sessionIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'sessionId'),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  sessionIdEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'sessionId', value: value),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  sessionIdGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'sessionId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  sessionIdLessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'sessionId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  sessionIdBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'sessionId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  statusEqualTo(JobStatus value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  statusGreaterThan(
    JobStatus value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  statusLessThan(
    JobStatus value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  statusBetween(
    JobStatus lower,
    JobStatus upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'status',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  statusStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  statusEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  statusContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  statusMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'status',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  statusIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'status', value: ''),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  statusIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'status', value: ''),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  updatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'updatedAt', value: value),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  updatedAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'updatedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  updatedAtLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'updatedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterFilterCondition>
  updatedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'updatedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension IsarConvertJobQueryObject
    on QueryBuilder<IsarConvertJob, IsarConvertJob, QFilterCondition> {}

extension IsarConvertJobQueryLinks
    on QueryBuilder<IsarConvertJob, IsarConvertJob, QFilterCondition> {}

extension IsarConvertJobQuerySortBy
    on QueryBuilder<IsarConvertJob, IsarConvertJob, QSortBy> {
  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy> sortByCommand() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'command', Sort.asc);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy>
  sortByCommandDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'command', Sort.desc);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy>
  sortByConvertedFilePath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'convertedFilePath', Sort.asc);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy>
  sortByConvertedFilePathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'convertedFilePath', Sort.desc);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy>
  sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy> sortByDuration() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'duration', Sort.asc);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy>
  sortByDurationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'duration', Sort.desc);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy> sortById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy> sortByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy>
  sortByInputFilePath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'inputFilePath', Sort.asc);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy>
  sortByInputFilePathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'inputFilePath', Sort.desc);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy>
  sortByOutputDirectoryPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'outputDirectoryPath', Sort.asc);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy>
  sortByOutputDirectoryPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'outputDirectoryPath', Sort.desc);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy>
  sortByOutputExtension() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'outputExtension', Sort.asc);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy>
  sortByOutputExtensionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'outputExtension', Sort.desc);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy>
  sortByOutputFileName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'outputFileName', Sort.asc);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy>
  sortByOutputFileNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'outputFileName', Sort.desc);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy> sortByProgress() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'progress', Sort.asc);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy>
  sortByProgressDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'progress', Sort.desc);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy> sortBySessionId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionId', Sort.asc);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy>
  sortBySessionIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionId', Sort.desc);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy> sortByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy>
  sortByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy> sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy>
  sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension IsarConvertJobQuerySortThenBy
    on QueryBuilder<IsarConvertJob, IsarConvertJob, QSortThenBy> {
  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy> thenByCommand() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'command', Sort.asc);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy>
  thenByCommandDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'command', Sort.desc);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy>
  thenByConvertedFilePath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'convertedFilePath', Sort.asc);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy>
  thenByConvertedFilePathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'convertedFilePath', Sort.desc);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy>
  thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy> thenByDuration() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'duration', Sort.asc);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy>
  thenByDurationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'duration', Sort.desc);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy>
  thenByInputFilePath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'inputFilePath', Sort.asc);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy>
  thenByInputFilePathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'inputFilePath', Sort.desc);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy> thenByIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isarId', Sort.asc);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy>
  thenByIsarIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isarId', Sort.desc);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy>
  thenByOutputDirectoryPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'outputDirectoryPath', Sort.asc);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy>
  thenByOutputDirectoryPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'outputDirectoryPath', Sort.desc);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy>
  thenByOutputExtension() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'outputExtension', Sort.asc);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy>
  thenByOutputExtensionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'outputExtension', Sort.desc);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy>
  thenByOutputFileName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'outputFileName', Sort.asc);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy>
  thenByOutputFileNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'outputFileName', Sort.desc);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy> thenByProgress() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'progress', Sort.asc);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy>
  thenByProgressDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'progress', Sort.desc);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy> thenBySessionId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionId', Sort.asc);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy>
  thenBySessionIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionId', Sort.desc);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy> thenByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy>
  thenByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy> thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QAfterSortBy>
  thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension IsarConvertJobQueryWhereDistinct
    on QueryBuilder<IsarConvertJob, IsarConvertJob, QDistinct> {
  QueryBuilder<IsarConvertJob, IsarConvertJob, QDistinct> distinctByCommand({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'command', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QDistinct>
  distinctByConvertedFilePath({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'convertedFilePath',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QDistinct>
  distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QDistinct> distinctByDuration() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'duration');
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QDistinct> distinctById({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'id', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QDistinct>
  distinctByInputFilePath({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'inputFilePath',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QDistinct>
  distinctByOutputDirectoryPath({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'outputDirectoryPath',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QDistinct>
  distinctByOutputExtension({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'outputExtension',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QDistinct>
  distinctByOutputFileName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'outputFileName',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QDistinct> distinctByProgress() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'progress');
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QDistinct>
  distinctBySessionId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sessionId');
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QDistinct> distinctByStatus({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'status', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<IsarConvertJob, IsarConvertJob, QDistinct>
  distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }
}

extension IsarConvertJobQueryProperty
    on QueryBuilder<IsarConvertJob, IsarConvertJob, QQueryProperty> {
  QueryBuilder<IsarConvertJob, int, QQueryOperations> isarIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isarId');
    });
  }

  QueryBuilder<IsarConvertJob, String, QQueryOperations> commandProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'command');
    });
  }

  QueryBuilder<IsarConvertJob, String, QQueryOperations>
  convertedFilePathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'convertedFilePath');
    });
  }

  QueryBuilder<IsarConvertJob, DateTime, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<IsarConvertJob, int?, QQueryOperations> durationProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'duration');
    });
  }

  QueryBuilder<IsarConvertJob, String, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<IsarConvertJob, String, QQueryOperations>
  inputFilePathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'inputFilePath');
    });
  }

  QueryBuilder<IsarConvertJob, String, QQueryOperations>
  outputDirectoryPathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'outputDirectoryPath');
    });
  }

  QueryBuilder<IsarConvertJob, String, QQueryOperations>
  outputExtensionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'outputExtension');
    });
  }

  QueryBuilder<IsarConvertJob, String, QQueryOperations>
  outputFileNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'outputFileName');
    });
  }

  QueryBuilder<IsarConvertJob, int?, QQueryOperations> progressProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'progress');
    });
  }

  QueryBuilder<IsarConvertJob, int?, QQueryOperations> sessionIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sessionId');
    });
  }

  QueryBuilder<IsarConvertJob, JobStatus, QQueryOperations> statusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'status');
    });
  }

  QueryBuilder<IsarConvertJob, DateTime, QQueryOperations> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }
}
