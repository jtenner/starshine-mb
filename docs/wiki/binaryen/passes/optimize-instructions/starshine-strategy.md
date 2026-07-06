---
kind: concept
status: supported
last_reviewed: 2026-07-06
sources:
  - ../../../raw/binaryen/2026-05-05-optimize-instructions-current-main-recheck.md
  - ../../../raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md
  - ../../../raw/binaryen/2026-04-22-optimize-instructions-primary-sources.md
  - ../../../raw/research/0444-2026-05-05-optimize-instructions-current-main-recheck.md
  - ../../../raw/research/0248-2026-04-22-optimize-instructions-primary-sources-and-implementation-followup.md
  - ../../../raw/research/0858-2026-06-25-optimize-instructions-oi-g-parameterized-memory-copy.md
  - ../../../raw/research/0859-2026-06-25-optimize-instructions-oi-m-tuple-optimization-boundary.md
  - ../../../raw/research/0860-2026-06-25-optimize-instructions-oi-g-mixed-parameterized-memory-copy.md
  - ../../../raw/research/0861-2026-06-25-optimize-instructions-oi-g-parameterized-byte-fill.md
  - ../../../raw/research/0862-2026-06-25-optimize-instructions-oi-g-multiparam-bulk-memory.md
  - ../../../raw/research/0863-2026-06-25-optimize-instructions-oi-m-earlier-later-neighbor.md
  - ../../../raw/research/0864-2026-06-25-optimize-instructions-oi-g-global-bulk-memory.md
  - ../../../raw/research/0865-2026-06-25-optimize-instructions-oi-m-trapping-sibling.md
  - ../../../raw/research/0866-2026-06-25-optimize-instructions-oi-g-v128-memory-copy.md
  - ../../../raw/research/0867-2026-06-25-optimize-instructions-oi-m-selected-trapping-lane.md
  - ../../../raw/research/0875-2026-06-25-optimize-instructions-oi-m-selected-trapping-two-later-siblings.md
  - ../../../raw/research/0876-2026-06-25-optimize-instructions-oi-g-local-dynamic-bulk.md
  - ../../../raw/research/0890-2026-06-25-optimize-instructions-oi-g-global-dynamic-bulk.md
  - ../../../raw/research/0892-2026-06-25-optimize-instructions-oi-g-size5-bulk-boundary.md
  - ../../../raw/research/0918-2026-06-25-optimize-instructions-oi-g-size6-bulk-boundary.md
  - ../../../raw/research/0910-2026-06-25-optimize-instructions-oi-g-size9-bulk-boundary.md
  - ../../../raw/research/0912-2026-06-25-optimize-instructions-oi-g-size11-bulk-boundary.md
  - ../../../raw/research/1142-2026-06-25-optimize-instructions-oi-g-size12-bulk-boundary.md
  - ../../../raw/research/0914-2026-06-25-optimize-instructions-oi-g-size13-bulk-boundary.md
  - ../../../raw/research/0916-2026-06-25-optimize-instructions-oi-g-size15-bulk-boundary.md
  - ../../../raw/research/1146-2026-06-25-optimize-instructions-oi-g-size17-bulk-boundary.md
  - ../../../raw/research/1148-2026-06-25-optimize-instructions-oi-g-size18-bulk-boundary.md
  - ../../../raw/research/1152-2026-06-26-optimize-instructions-oi-g-size19-bulk-boundary.md
  - ../../../raw/research/1158-2026-06-26-optimize-instructions-oi-g-size20-bulk-boundary.md
  - ../../../raw/research/1160-2026-06-26-optimize-instructions-oi-g-size21-bulk-boundary.md
  - ../../../raw/research/1162-2026-06-26-optimize-instructions-oi-g-size22-bulk-boundary.md
  - ../../../raw/research/1164-2026-06-26-optimize-instructions-oi-g-size23-bulk-boundary.md
  - ../../../raw/research/1166-2026-06-26-optimize-instructions-oi-g-size24-bulk-boundary.md
  - ../../../raw/research/1168-2026-06-26-optimize-instructions-oi-g-size25-bulk-boundary.md
  - ../../../raw/research/1170-2026-06-26-optimize-instructions-oi-g-size26-bulk-boundary.md
  - ../../../raw/research/1172-2026-06-26-optimize-instructions-oi-g-size27-bulk-boundary.md
  - ../../../raw/research/1174-2026-06-26-optimize-instructions-oi-g-size28-bulk-boundary.md
  - ../../../raw/research/1176-2026-06-26-optimize-instructions-oi-g-size29-bulk-boundary.md
  - ../../../raw/research/1178-2026-06-26-optimize-instructions-oi-g-size30-bulk-boundary.md
  - ../../../raw/research/1180-2026-06-26-optimize-instructions-oi-g-size31-bulk-boundary.md
  - ../../../raw/research/1182-2026-06-26-optimize-instructions-oi-g-size32-bulk-boundary.md
  - ../../../raw/research/1184-2026-06-26-optimize-instructions-oi-g-size33-bulk-boundary.md
  - ../../../raw/research/1186-2026-06-26-optimize-instructions-oi-g-size34-bulk-boundary.md
  - ../../../raw/research/1188-2026-06-26-optimize-instructions-oi-g-size35-bulk-boundary.md
  - ../../../raw/research/1208-2026-06-26-optimize-instructions-oi-g-size36-bulk-boundary.md
  - ../../../raw/research/0877-2026-06-25-optimize-instructions-oi-m-selected-trapping-two-earlier-siblings.md
  - ../../../raw/research/0878-2026-06-25-optimize-instructions-oi-d-i64-signext-equality-boundary.md
  - ../../../raw/research/0879-2026-06-25-optimize-instructions-oi-m-selected-trapping-two-earlier-one-later.md
  - ../../../raw/research/0880-2026-06-25-optimize-instructions-oi-g-stack-v128-memory-copy.md
  - ../../../raw/research/0881-2026-06-25-optimize-instructions-oi-m-selected-trapping-two-earlier-two-later.md
  - ../../../raw/research/0882-2026-06-25-optimize-instructions-oi-g-call-backed-v128-memory-fill-boundary.md
  - ../../../raw/research/0884-2026-06-25-optimize-instructions-oi-g-local-v128-memory-fill-boundary.md
  - ../../../raw/research/0883-2026-06-25-optimize-instructions-oi-m-selected-trapping-two-earlier-three-later.md
  - ../../../raw/research/0885-2026-06-25-optimize-instructions-oi-m-selected-trapping-two-earlier-four-later.md
  - ../../../raw/research/0886-2026-06-25-optimize-instructions-oi-g-memory-copy-size3-boundary.md
  - ../../../raw/research/0887-2026-06-25-optimize-instructions-oi-m-selected-trapping-two-earlier-five-later.md
  - ../../../raw/research/0891-2026-06-25-optimize-instructions-oi-m-selected-trapping-two-earlier-six-later.md
  - ../../../raw/research/0893-2026-06-25-optimize-instructions-oi-m-selected-trapping-two-earlier-seven-later.md
  - ../../../raw/research/0895-2026-06-25-optimize-instructions-oi-m-selected-trapping-two-earlier-eight-later.md
  - ../../../raw/research/0900-2026-06-25-optimize-instructions-oi-d-maxbits-signed-spelling.md
  - ../../../raw/research/0902-2026-06-25-optimize-instructions-oi-d-local-maxbits.md
  - ../../../raw/research/0904-2026-06-25-optimize-instructions-oi-d-wrap-maxbits.md
  - ../../../raw/research/0906-2026-06-25-optimize-instructions-oi-d-dynamic-shift-maxbits-boundary.md
  - ../../../raw/research/0908-2026-06-25-optimize-instructions-oi-d-i64-dynamic-shift-maxbits-boundary.md
  - ../../../raw/research/1150-2026-06-25-optimize-instructions-oi-d-shift-rotate-mask-coverage.md
  - ../../../raw/research/1154-2026-06-26-optimize-instructions-oi-d-signext-unsigned-top.md
  - ../../../raw/research/1156-2026-06-26-optimize-instructions-oi-d-i64-signext-unsigned-top.md
  - ../../../raw/research/1323-2026-06-26-optimize-instructions-oi-d-double-eqz.md
  - ../../../raw/research/1325-2026-06-26-optimize-instructions-oi-d-zero-compare-eqz.md
  - ../../../raw/research/1327-2026-06-26-optimize-instructions-oi-d-signed-domain-edge.md
  - ../../../raw/research/1329-2026-06-27-optimize-instructions-oi-d-eqz-relational-compare.md
  - ../../../raw/research/1331-2026-06-27-optimize-instructions-oi-d-eqz-float-eqne.md
  - ../../../raw/research/1333-2026-06-27-optimize-instructions-oi-f-demorgan-and-eqz.md
  - ../../../raw/research/1335-2026-06-27-optimize-instructions-oi-f-boolean-const-select.md
  - ../../../raw/research/1337-2026-06-27-optimize-instructions-oi-f-select-eqz-condition.md
  - ../../../raw/research/1339-2026-06-27-optimize-instructions-oi-f-select-zero-compare-condition.md
  - ../../../raw/research/1341-2026-06-27-optimize-instructions-oi-f-i64-eqz-boolean-select.md
  - ../../../raw/research/0901-2026-06-25-optimize-instructions-oi-m-selected-fourth-multiresult-boundary.md
  - ../../../raw/research/0903-2026-06-25-optimize-instructions-oi-m-selected-fifth-multiresult-boundary.md
  - ../../../raw/research/0905-2026-06-25-optimize-instructions-oi-m-selected-sixth-multiresult-boundary.md
  - ../../../raw/research/0907-2026-06-25-optimize-instructions-oi-m-selected-seventh-multiresult-boundary.md
  - ../../../raw/research/0909-2026-06-25-optimize-instructions-oi-m-selected-eighth-multiresult-boundary.md
  - ../../../raw/research/0911-2026-06-25-optimize-instructions-oi-m-selected-ninth-multiresult-boundary.md
  - ../../../raw/research/0913-2026-06-25-optimize-instructions-oi-m-selected-tenth-multiresult-boundary.md
  - ../../../raw/research/0915-2026-06-25-optimize-instructions-oi-m-selected-eleventh-multiresult-boundary.md
  - ../../../raw/research/0917-2026-06-25-optimize-instructions-oi-m-selected-twelfth-multiresult-boundary.md
  - ../../../raw/research/0919-2026-06-25-optimize-instructions-oi-m-selected-thirteenth-multiresult-boundary.md
  - ../../../raw/research/1141-2026-06-25-optimize-instructions-oi-m-selected-fourteenth-multiresult-boundary.md
  - ../../../raw/research/1143-2026-06-25-optimize-instructions-oi-m-direct-selected-fifteenth-boundary.md
  - ../../../raw/research/1145-2026-06-25-optimize-instructions-oi-m-direct-selected-sixteenth-boundary.md
  - ../../../raw/research/1147-2026-06-25-optimize-instructions-oi-m-direct-selected-seventeenth-boundary.md
  - ../../../raw/research/1149-2026-06-25-optimize-instructions-oi-m-direct-selected-eighteenth-boundary.md
  - ../../../raw/research/1151-2026-06-25-optimize-instructions-oi-m-direct-selected-nineteenth-boundary.md
  - ../../../raw/research/1153-2026-06-26-optimize-instructions-oi-m-tuple-optimization-two-effects-boundary.md
  - ../../../raw/research/1155-2026-06-26-optimize-instructions-oi-m-tuple-optimization-three-effects-boundary.md
  - ../../../raw/research/1157-2026-06-26-optimize-instructions-oi-m-tuple-optimization-four-effects-boundary.md
  - ../../../raw/research/1159-2026-06-26-optimize-instructions-oi-m-tuple-optimization-five-effects-boundary.md
  - ../../../raw/research/1161-2026-06-26-optimize-instructions-oi-m-tuple-optimization-six-effects-boundary.md
  - ../../../raw/research/1163-2026-06-26-optimize-instructions-oi-m-tuple-optimization-seven-effects-boundary.md
  - ../../../raw/research/1165-2026-06-26-optimize-instructions-oi-m-tuple-optimization-eight-effects-boundary.md
  - ../../../raw/research/1167-2026-06-26-optimize-instructions-oi-m-tuple-optimization-nine-effects-boundary.md
  - ../../../raw/research/1169-2026-06-26-optimize-instructions-oi-m-tuple-optimization-ten-effects-boundary.md
  - ../../../raw/research/1171-2026-06-26-optimize-instructions-oi-m-tuple-optimization-eleven-effects-boundary.md
  - ../../../raw/research/1173-2026-06-26-optimize-instructions-oi-m-tuple-optimization-twelve-effects-boundary.md
  - ../../../raw/research/1175-2026-06-26-optimize-instructions-oi-m-tuple-optimization-thirteen-effects-boundary.md
  - ../../../raw/research/1177-2026-06-26-optimize-instructions-oi-m-tuple-optimization-fourteen-effects-boundary.md
  - ../../../raw/research/1179-2026-06-26-optimize-instructions-oi-m-tuple-optimization-fifteen-effects-boundary.md
  - ../../../raw/research/1181-2026-06-26-optimize-instructions-oi-m-tuple-optimization-sixteen-effects-boundary.md
  - ../../../raw/research/1183-2026-06-26-optimize-instructions-oi-m-tuple-optimization-seventeen-effects-boundary.md
  - ../../../raw/research/1185-2026-06-26-optimize-instructions-oi-m-tuple-optimization-eighteen-effects-boundary.md
  - ../../../raw/research/1187-2026-06-26-optimize-instructions-oi-m-tuple-optimization-nineteen-effects-boundary.md
  - ../../../raw/research/1189-2026-06-26-optimize-instructions-oi-m-tuple-optimization-twenty-effects-boundary.md
  - ../../../raw/research/1191-2026-06-26-optimize-instructions-oi-m-tuple-optimization-twenty-one-effects-boundary.md
  - ../../../raw/research/1193-2026-06-26-optimize-instructions-oi-m-tuple-optimization-twenty-two-effects-boundary.md
  - ../../../raw/research/1195-2026-06-26-optimize-instructions-oi-m-tuple-optimization-twenty-three-effects-boundary.md
  - ../../../raw/research/1197-2026-06-26-optimize-instructions-oi-m-tuple-optimization-twenty-four-effects-boundary.md
  - ../../../raw/research/1199-2026-06-26-optimize-instructions-oi-m-tuple-optimization-twenty-five-effects-boundary.md
  - ../../../raw/research/1201-2026-06-26-optimize-instructions-oi-m-tuple-optimization-twenty-six-effects-boundary.md
  - ../../../raw/research/1203-2026-06-26-optimize-instructions-oi-m-tuple-optimization-twenty-seven-effects-boundary.md
  - ../../../raw/research/1205-2026-06-26-optimize-instructions-oi-m-tuple-optimization-twenty-eight-effects-boundary.md
  - ../../../raw/research/1207-2026-06-26-optimize-instructions-oi-m-tuple-optimization-twenty-nine-effects-boundary.md
  - ../../../raw/research/1209-2026-06-26-optimize-instructions-oi-m-tuple-optimization-thirty-effects-boundary.md
  - ../../../raw/research/1212-2026-06-26-optimize-instructions-oi-m-tuple-optimization-thirty-one-effects-boundary.md
  - ../../../raw/research/1215-2026-06-26-optimize-instructions-oi-m-tuple-optimization-thirty-two-effects-boundary.md
  - ../../../raw/research/1217-2026-06-26-optimize-instructions-oi-m-tuple-optimization-thirty-three-effects-boundary.md
  - ../../../raw/research/1218-2026-06-26-optimize-instructions-oi-f-identical-select-arms.md
  - ../../../raw/research/1219-2026-06-26-optimize-instructions-oi-m-tuple-optimization-thirty-four-effects-boundary.md
  - ../../../raw/research/1220-2026-06-26-optimize-instructions-oi-m-tuple-optimization-thirty-five-effects-boundary.md
  - ../../../raw/research/1221-2026-06-26-optimize-instructions-oi-m-tuple-optimization-thirty-six-effects-boundary.md
  - ../../../raw/research/1222-2026-06-26-optimize-instructions-oi-m-tuple-optimization-thirty-seven-effects-boundary.md
  - ../../../raw/research/1223-2026-06-26-optimize-instructions-oi-m-tuple-optimization-thirty-eight-effects-boundary.md
  - ../../../raw/research/1224-2026-06-26-optimize-instructions-oi-m-tuple-optimization-thirty-nine-effects-boundary.md
  - ../../../raw/research/1225-2026-06-26-optimize-instructions-oi-m-tuple-optimization-forty-effects-boundary.md
  - ../../../raw/research/1226-2026-06-26-optimize-instructions-oi-m-tuple-optimization-forty-one-effects-boundary.md
  - ../../../raw/research/1227-2026-06-26-optimize-instructions-oi-m-tuple-optimization-forty-two-effects-boundary.md
  - ../../../raw/research/1228-2026-06-26-optimize-instructions-oi-m-tuple-optimization-forty-three-effects-boundary.md
  - ../../../raw/research/1229-2026-06-26-optimize-instructions-oi-m-tuple-optimization-forty-four-effects-boundary.md
  - ../../../raw/research/1230-2026-06-26-optimize-instructions-oi-m-tuple-optimization-forty-five-effects-boundary.md
  - ../../../raw/research/1231-2026-06-26-optimize-instructions-oi-m-tuple-optimization-forty-six-effects-boundary.md
  - ../../../raw/research/1232-2026-06-26-optimize-instructions-oi-m-tuple-optimization-forty-seven-effects-boundary.md
  - ../../../raw/research/1233-2026-06-26-optimize-instructions-oi-m-tuple-optimization-forty-eight-effects-boundary.md
  - ../../../raw/research/1234-2026-06-26-optimize-instructions-oi-m-tuple-optimization-forty-nine-effects-boundary.md
  - ../../../raw/research/1235-2026-06-26-optimize-instructions-oi-m-tuple-optimization-fifty-effects-boundary.md
  - ../../../raw/research/1236-2026-06-26-optimize-instructions-oi-m-tuple-optimization-fifty-one-effects-boundary.md
  - ../../../raw/research/1237-2026-06-26-optimize-instructions-oi-f-identical-numeric-select-arms.md
  - ../../../raw/research/1239-2026-06-26-optimize-instructions-oi-f-identical-i64-unary-select-arms.md
  - ../../../raw/research/1241-2026-06-26-optimize-instructions-oi-f-identical-float-unary-select-arms.md
  - ../../../raw/research/1243-2026-06-26-optimize-instructions-oi-f-identical-float-binary-select-arms.md
  - ../../../raw/research/1245-2026-06-26-optimize-instructions-oi-f-identical-float-minmax-select-arms.md
  - ../../../raw/research/1247-2026-06-26-optimize-instructions-oi-f-identical-compare-select-arms.md
  - ../../../raw/research/1249-2026-06-26-optimize-instructions-oi-f-identical-conversion-select-arms.md
  - ../../../raw/research/1251-2026-06-26-optimize-instructions-oi-f-identical-v128-select-arms.md
  - ../../../raw/research/1253-2026-06-26-optimize-instructions-oi-f-identical-v128-splat-select-arms.md
  - ../../../raw/research/1257-2026-06-26-optimize-instructions-oi-f-identical-i64-local-local-select-arms.md
  - ../../../raw/research/1259-2026-06-26-optimize-instructions-oi-f-identical-i64-mul-local-local-select-arms.md
  - ../../../raw/research/1261-2026-06-26-optimize-instructions-oi-f-identical-i32-mul-local-local-select-arms.md
  - ../../../raw/research/1263-2026-06-26-optimize-instructions-oi-f-identical-i32-sub-local-local-select-arms.md
  - ../../../raw/research/1265-2026-06-26-optimize-instructions-oi-f-identical-i64-sub-local-local-select-arms.md
  - ../../../raw/research/1267-2026-06-26-optimize-instructions-oi-f-identical-i32-bitwise-local-local-select-arms.md
  - ../../../raw/research/1269-2026-06-26-optimize-instructions-oi-f-identical-i64-bitwise-local-local-select-arms.md
  - ../../../raw/research/1271-2026-06-26-optimize-instructions-oi-f-identical-shift-rotate-local-local-select-arms.md
  - ../../../raw/research/1273-2026-06-26-optimize-instructions-oi-f-identical-compare-local-local-select-arms.md
  - ../../../raw/research/1275-2026-06-26-optimize-instructions-oi-f-identical-float-compare-local-local-select-arms.md
  - ../../../raw/research/1277-2026-06-26-optimize-instructions-oi-f-identical-float-binary-local-local-select-arms.md
  - ../../../raw/research/1279-2026-06-26-optimize-instructions-oi-f-identical-leaf-select-effectful-condition.md
  - ../../../raw/research/1281-2026-06-26-optimize-instructions-oi-f-identical-i32add-effectful-condition.md
  - ../../../raw/research/1283-2026-06-26-optimize-instructions-oi-f-identical-i64add-effectful-condition.md
  - ../../../raw/research/1285-2026-06-26-optimize-instructions-oi-f-identical-intmul-effectful-condition.md
  - ../../../raw/research/1287-2026-06-26-optimize-instructions-oi-f-identical-intbitwise-effectful-condition.md
  - ../../../raw/research/1289-2026-06-26-optimize-instructions-oi-f-identical-shift-rotate-effectful-condition.md
  - ../../../raw/research/1291-2026-06-26-optimize-instructions-oi-f-identical-sub-effectful-condition.md
  - ../../../raw/research/1293-2026-06-26-optimize-instructions-oi-f-identical-intcompare-effectful-condition.md
  - ../../../raw/research/1295-2026-06-26-optimize-instructions-oi-f-identical-floatcompare-effectful-condition.md
  - ../../../raw/research/1297-2026-06-26-optimize-instructions-oi-f-identical-floatbinary-effectful-condition.md
  - ../../../raw/research/1299-2026-06-26-optimize-instructions-oi-f-identical-floatunary-effectful-condition.md
  - ../../../raw/research/1301-2026-06-26-optimize-instructions-oi-f-identical-float-localconst-effectful-condition.md
  - ../../../raw/research/1303-2026-06-26-optimize-instructions-oi-f-identical-int-localconst-effectful-condition.md
  - ../../../raw/research/1305-2026-06-26-optimize-instructions-oi-f-identical-v128-splat-effectful-condition.md
  - ../../../raw/research/1307-2026-06-26-optimize-instructions-oi-f-identical-refi31-effectful-condition.md
  - ../../../raw/research/1311-2026-06-26-optimize-instructions-oi-f-identical-v128const-effectful-condition.md
  - ../../../raw/research/1313-2026-06-26-optimize-instructions-oi-f-identical-int-unary-effectful-condition.md
  - ../../../raw/research/1315-2026-06-26-optimize-instructions-oi-f-identical-float-conversion-effectful-condition.md
  - ../../../raw/research/1317-2026-06-26-optimize-instructions-oi-f-mutable-global-effectful-condition-boundary.md
  - ../../../raw/research/1321-2026-06-26-optimize-instructions-oi-f-immutable-global-effectful-condition.md
  - ../../../raw/research/1319-2026-06-26-optimize-instructions-oi-k-array-new-default-get-large-len-boundary.md
  - ../../../raw/research/1312-2026-06-26-optimize-instructions-oi-m-tuple-optimization-eighty-nine-effects-boundary.md
  - ../../../raw/research/1314-2026-06-26-optimize-instructions-oi-m-tuple-optimization-ninety-effects-boundary.md
  - ../../../raw/research/1316-2026-06-26-optimize-instructions-oi-m-tuple-optimization-ninety-one-effects-boundary.md
  - ../../../raw/research/1318-2026-06-26-optimize-instructions-oi-m-tuple-optimization-ninety-two-effects-boundary.md
  - ../../../raw/research/1320-2026-06-26-optimize-instructions-oi-m-tuple-optimization-ninety-three-effects-boundary.md
  - ../../../raw/research/1322-2026-06-26-optimize-instructions-oi-m-tuple-optimization-ninety-four-effects-boundary.md
  - ../../../raw/research/1324-2026-06-26-optimize-instructions-oi-m-tuple-optimization-ninety-five-effects-boundary.md
  - ../../../raw/research/1326-2026-06-26-optimize-instructions-oi-m-tuple-optimization-ninety-six-effects-boundary.md
  - ../../../raw/research/1328-2026-06-26-optimize-instructions-oi-m-tuple-optimization-ninety-seven-effects-boundary.md
  - ../../../raw/research/1330-2026-06-27-optimize-instructions-oi-m-tuple-optimization-ninety-eight-effects-boundary.md
  - ../../../raw/research/1332-2026-06-27-optimize-instructions-oi-m-tuple-optimization-ninety-nine-effects-boundary.md
  - ../../../raw/research/1334-2026-06-27-optimize-instructions-oi-m-tuple-optimization-one-hundred-effects-boundary.md
  - ../../../raw/research/1336-2026-06-27-optimize-instructions-oi-m-tuple-optimization-one-hundred-one-effects-boundary.md
  - ../../../raw/research/1338-2026-06-27-optimize-instructions-oi-m-tuple-optimization-one-hundred-two-effects-boundary.md
  - ../../../raw/research/1340-2026-06-27-optimize-instructions-oi-m-tuple-optimization-one-hundred-three-effects-boundary.md
  - ../../../raw/research/1342-2026-06-27-optimize-instructions-oi-m-tuple-optimization-one-hundred-four-effects-boundary.md
  - ../../../raw/research/1238-2026-06-26-optimize-instructions-oi-m-tuple-optimization-fifty-two-effects-boundary.md
  - ../../../raw/research/1240-2026-06-26-optimize-instructions-oi-m-tuple-optimization-fifty-three-effects-boundary.md
  - ../../../raw/research/1242-2026-06-26-optimize-instructions-oi-m-tuple-optimization-fifty-four-effects-boundary.md
  - ../../../raw/research/1244-2026-06-26-optimize-instructions-oi-m-tuple-optimization-fifty-five-effects-boundary.md
  - ../../../raw/research/1246-2026-06-26-optimize-instructions-oi-m-tuple-optimization-fifty-six-effects-boundary.md
  - ../../../raw/research/1248-2026-06-26-optimize-instructions-oi-m-tuple-optimization-fifty-seven-effects-boundary.md
  - ../../../raw/research/1250-2026-06-26-optimize-instructions-oi-m-tuple-optimization-fifty-eight-effects-boundary.md
  - ../../../raw/research/1252-2026-06-26-optimize-instructions-oi-m-tuple-optimization-fifty-nine-effects-boundary.md
  - ../../../raw/research/1254-2026-06-26-optimize-instructions-oi-m-tuple-optimization-sixty-effects-boundary.md
  - ../../../raw/research/1256-2026-06-26-optimize-instructions-oi-m-tuple-optimization-sixty-one-effects-boundary.md
  - ../../../raw/research/1258-2026-06-26-optimize-instructions-oi-m-tuple-optimization-sixty-two-effects-boundary.md
  - ../../../raw/research/1260-2026-06-26-optimize-instructions-oi-m-tuple-optimization-sixty-three-effects-boundary.md
  - ../../../raw/research/1262-2026-06-26-optimize-instructions-oi-m-tuple-optimization-sixty-four-effects-boundary.md
  - ../../../raw/research/1264-2026-06-26-optimize-instructions-oi-m-tuple-optimization-sixty-five-effects-boundary.md
  - ../../../raw/research/1266-2026-06-26-optimize-instructions-oi-m-tuple-optimization-sixty-six-effects-boundary.md
  - ../../../raw/research/1268-2026-06-26-optimize-instructions-oi-m-tuple-optimization-sixty-seven-effects-boundary.md
  - ../../../raw/research/1270-2026-06-26-optimize-instructions-oi-m-tuple-optimization-sixty-eight-effects-boundary.md
  - ../../../raw/research/1272-2026-06-26-optimize-instructions-oi-m-tuple-optimization-sixty-nine-effects-boundary.md
  - ../../../raw/research/1274-2026-06-26-optimize-instructions-oi-m-tuple-optimization-seventy-effects-boundary.md
  - ../../../raw/research/1276-2026-06-26-optimize-instructions-oi-m-tuple-optimization-seventy-one-effects-boundary.md
  - ../../../raw/research/1278-2026-06-26-optimize-instructions-oi-m-tuple-optimization-seventy-two-effects-boundary.md
  - ../../../raw/research/1280-2026-06-26-optimize-instructions-oi-m-tuple-optimization-seventy-three-effects-boundary.md
  - ../../../raw/research/1282-2026-06-26-optimize-instructions-oi-m-tuple-optimization-seventy-four-effects-boundary.md
  - ../../../raw/research/1284-2026-06-26-optimize-instructions-oi-m-tuple-optimization-seventy-five-effects-boundary.md
  - ../../../raw/research/1286-2026-06-26-optimize-instructions-oi-m-tuple-optimization-seventy-six-effects-boundary.md
  - ../../../raw/research/1288-2026-06-26-optimize-instructions-oi-m-tuple-optimization-seventy-seven-effects-boundary.md
  - ../../../raw/research/1290-2026-06-26-optimize-instructions-oi-m-tuple-optimization-seventy-eight-effects-boundary.md
  - ../../../raw/research/1292-2026-06-26-optimize-instructions-oi-m-tuple-optimization-seventy-nine-effects-boundary.md
  - ../../../raw/research/1294-2026-06-26-optimize-instructions-oi-m-tuple-optimization-eighty-effects-boundary.md
  - ../../../raw/research/1296-2026-06-26-optimize-instructions-oi-m-tuple-optimization-eighty-one-effects-boundary.md
  - ../../../raw/research/1298-2026-06-26-optimize-instructions-oi-m-tuple-optimization-eighty-two-effects-boundary.md
  - ../../../raw/research/1300-2026-06-26-optimize-instructions-oi-m-tuple-optimization-eighty-three-effects-boundary.md
  - ../../../raw/research/1302-2026-06-26-optimize-instructions-oi-m-tuple-optimization-eighty-four-effects-boundary.md
  - ../../../raw/research/1304-2026-06-26-optimize-instructions-oi-m-tuple-optimization-eighty-five-effects-boundary.md
  - ../../../raw/research/1306-2026-06-26-optimize-instructions-oi-m-tuple-optimization-eighty-six-effects-boundary.md
  - ../../../raw/research/1308-2026-06-26-optimize-instructions-oi-m-tuple-optimization-eighty-seven-effects-boundary.md
  - ../../../raw/research/1310-2026-06-26-optimize-instructions-oi-m-tuple-optimization-eighty-eight-effects-boundary.md
  - ../../../raw/research/1190-2026-06-26-optimize-instructions-oi-d-const-eq-ne.md
  - ../../../raw/research/1192-2026-06-26-optimize-instructions-oi-d-unsigned-domain-edge.md
  - ../../../raw/research/1194-2026-06-26-optimize-instructions-oi-d-unsigned-const-rel.md
  - ../../../raw/research/1196-2026-06-26-optimize-instructions-oi-d-signed-const-rel-boundary.md
  - ../../../raw/research/1198-2026-06-26-optimize-instructions-oi-d-i64-extend-i32-u-maxbits.md
  - ../../../raw/research/1200-2026-06-26-optimize-instructions-oi-d-i64-extend-i32-u-narrow-maxbits.md
  - ../../../raw/research/1202-2026-06-26-optimize-instructions-oi-d-signed-zero-lhs-const-rel.md
  - ../../../raw/research/1204-2026-06-26-optimize-instructions-oi-d-negative-signed-const-rel-boundary.md
  - ../../../raw/research/1206-2026-06-26-optimize-instructions-oi-d-nonnegative-signed-const-rel-boundary.md
  - ../../../raw/research/1210-2026-06-26-optimize-instructions-oi-d-nonnegative-negative-signed-const-rel.md
  - ../../../raw/research/1213-2026-06-26-optimize-instructions-oi-d-signed-zero-rhs-const-rel-boundary.md
  - ../../../raw/research/1211-2026-06-26-optimize-instructions-oi-g-size37-bulk-boundary.md
  - ../../../raw/research/1214-2026-06-26-optimize-instructions-oi-g-size38-bulk-boundary.md
  - ../../../raw/research/1216-2026-06-26-optimize-instructions-oi-g-size39-bulk-boundary.md
  - ../../../../../src/passes/optimize_instructions.mbt
  - ../../../../../src/passes/optimize_instructions_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./gc-casts-call_ref-and-trap-sensitive-rewrites.md
  - ./wat-shapes.md
  - ./starshine-hot-ir-strategy.md
  - ../tracker.md
  - ../../no-dwarf-default-optimize-path.md
---

# Current Starshine `optimize-instructions` strategy

This page is the local strategy overview.
For the exact helper walk and finer-grained code map, use [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md).

## Short version

Current Starshine `src/passes/optimize_instructions.mbt` is a real HOT pass, but it is still narrower than Binaryen `OptimizeInstructions.cpp`. The `[O4Z-AUDIT-OI-A]` `version_130` matrix now makes that gap actionable by assigning each upstream source/lit family to current coverage, an explicit local boundary, or a follow-up slice.

The implemented center of gravity is:

- exact binary constant folding and constant integer `eq` / `ne` compare folding
- non-constant `eqz` / compare-to-zero rewrites, same-local integer compare and binary operand folding, endpoint unsigned-domain compare folds (`x <_u 0`, `x >=_u 0`, `x >_u UINT_MAX`, `x <=_u UINT_MAX`) with effect preservation, side-effect-free signed-domain endpoint folds (`x <s INT_MIN`, `x >=s INT_MIN`, `x >s INT_MAX`, `x <=s INT_MAX`) with effectful signed endpoint compares intentionally kept to match the oracle boundary, pure and effect-preserving i32/i64 masked unsigned-compare folds plus first pure/effect-preserving i32/i64 `shr_u` bounded unsigned-compare folds, first straight-line local-carried, `i32.wrap_i64`, and `i64.extend_i32_u` unsigned max facts including narrowed child facts, first direct nonnegative signed-relational folds and signed-to-unsigned compare spellings, signed zero-lhs constant relational folds, signed zero-rhs constant relational keep/canonicalize boundary coverage, and relational constant canonicalization
- commutative operand ordering with HOT use-def safety guards
- add/sub/mul/shift rewrites, including constant shift/rotate effective-amount masking (`31`/`63`) through existing constant-fold/identity machinery
- constant-`if` folding and constant-condition / identical-pure-arm local/global/ref.null/ref.func/ref.i31 (including narrow same-order `i32.add(local.get, i32.const)`, `i32.sub(local.get, i32.const)`, `i32.mul(local.get, i32.const)`, `i32.and(local.get, i32.const)`, `i32.or(local.get, i32.const)`, `i32.xor(local.get, i32.const)`, `i32.shl(local.get, i32.const)`, `i32.shr_u(local.get, i32.const)`, `i32.shr_s(local.get, i32.const)`, `i32.rotl(local.get, i32.const)`, `i32.rotr(local.get, i32.const)`, `i32.eqz(local.get)`, `i32.clz(local.get)`, `i32.ctz(local.get)`, `i32.popcnt(local.get)`, `i32.extend8_s(local.get)`, `i32.extend16_s(local.get)`, direct `i32.trunc_sat_f32_*` / `i32.trunc_sat_f64_*`, direct `i32.reinterpret_f32`, direct `i32.wrap_i64`, and same-order direct `i32.div_s` / `i32.div_u` / `i32.rem_s` / `i32.rem_u(local.get, i32.const)` payload shells)/integer/float `select` cleanup, plus direct same-order `i32`/`i64` local/constant numeric expression-arm folds for matching binary shells and direct i64 unary local shells, direct f32/f64 unary/conversion local shells, direct f32/f64 same-order local/constant binary shells including min/max, direct byte-identical `v128.const` arms, direct same-instruction/same-local SIMD splat arms, narrow direct `i32.add(local.get, local.get)` / `i32.mul(local.get, local.get)` / `i32.sub(local.get, local.get)` / `i32.and(local.get, local.get)` / `i32.or(local.get, local.get)` / `i32.xor(local.get, local.get)` / `i32.shl(local.get, local.get)` / `i32.shr_s(local.get, local.get)` / `i32.shr_u(local.get, local.get)` / `i32.rotl(local.get, local.get)` / `i32.rotr(local.get, local.get)` / `i64.add(local.get, local.get)` / `i64.mul(local.get, local.get)` / `i64.sub(local.get, local.get)` / `i64.and(local.get, local.get)` / `i64.or(local.get, local.get)` / `i64.xor(local.get, local.get)` / `i64.shl(local.get, local.get)` / `i64.shr_s(local.get, local.get)` / `i64.shr_u(local.get, local.get)` / `i64.rotl(local.get, local.get)` / `i64.rotr(local.get, local.get)` same-ordered-local shells plus direct i32/i64 and f32/f64 compare same-ordered-local shells and direct f32/f64 binary same-ordered-local shells, and effectful-condition identical-arm cleanup for direct leaves plus the nontrapping same-ordered `i32.add(local.get, local.get)`, `i64.add(local.get, local.get)`, `i32.sub(local.get, local.get)`, `i64.sub(local.get, local.get)`, `i32.mul(local.get, local.get)`, `i64.mul(local.get, local.get)`, `i32.and(local.get, local.get)`, `i32.or(local.get, local.get)`, `i32.xor(local.get, local.get)`, `i64.and(local.get, local.get)`, `i64.or(local.get, local.get)`, `i64.xor(local.get, local.get)`, i32/i64 shift, i32/i64 rotate, i32/i64 integer compare, i32/i64 nontrapping same-ordered local/constant add/sub/mul/bitwise/shift/rotate/compare shells, and f32/f64 float unary/conversion/compare/binary same-ordered-local shells plus f32/f64 float binary same-ordered local/constant shells, nontrapping `ref.i31` local/constant/i32 local-constant/unary and same-ordered i32 local/local add/sub/mul/bitwise/shift/rotate/compare payload shells, byte-identical `v128.const` arms, same-instruction direct-local v128 splat shells, and same-index immutable `global.get` arms proven through module context; mutable `global.get` arms remain side-effect-free-condition only and are not moved across effectful conditions
- nested boolean-`if` normalization, `eqz` wrapping, the narrow direct De Morgan `i32.and(i32.eqz X, i32.eqz Y)` to `i32.eqz(i32.or X Y)` cleanup, direct boolean constant `select` cleanup for i32 `1/0` and `0/1` arms, direct `i32.eqz` select-condition cleanup by swapping select arms, direct `i32.eq` / `i32.ne` zero select-condition cleanup by dropping the redundant compare, and direct `i64.eqz` boolean-select cleanup for exact i32 `1/0` and `0/1` arms while leaving non-boolean value selects unchanged
- duplicate-branch collapse in then-regions
- the OI-J direct-call exact descriptor-miss family under semantic preconditions: ordered nontrapping `local.get*`, scalar constant (`i32.const`/`i64.const` with the shared scanner predicate also covering `f32.const`/`f64.const`), or `global.get` ref args; direct strict-subtype ref call; ordered nontrapping `local.get*`, scalar constant, or `global.get` descriptor args; direct exact-descriptor call; and source-order-preserving call/drop/unreachable output
- the sibling OI-J pure-reference/direct-descriptor-call or exact `ref.func` + `call_ref` descriptor-producer exact descriptor-miss family under semantic preconditions: pure strict-subtype `local.get` reference operand, or a direct strict-subtype reference call for the call_ref descriptor-producer subset; ordered nontrapping `local.get*`, scalar constant (`i32.const`/`i64.const` with the shared scanner predicate also covering `f32.const`/`f64.const`), `global.get`, branch-free value-block descriptor-call args, no-parameter direct value-call descriptor-call args, parameterized direct value-call descriptor-call args with ordered nontrapping leaf operands, no-parameter direct non-null reference-result descriptor-call args, parameterized direct non-null reference-result descriptor-call args with ordered nontrapping leaf operands, scalar-producer `local.tee` descriptor-call args, pure nontrapping-leaf `select` descriptor-call args, or stack-form trapping integer div/rem scalar descriptor-call args with nontrapping leaves; direct descriptor call with matching parameter count and exact target descriptor result, or `ref.func` plus `call_ref` whose direct target and static call_ref type both return an exact non-null descriptor for the cast target with matching parameter count; and source-order-preserving `desc args; call desc; drop; unreachable` output
- the sibling OI-J pure-local direct-call exact descriptor-success family under semantic preconditions: ordered `local.get*` ref args, direct exact non-null target ref call, ordered `local.get*` descriptor args, direct exact target descriptor call, and source-order-preserving `ref args; call ref; desc args; call desc; drop` output; exact-success casts with scalar-constant or `global.get` direct-call arguments are a Binaryen-backed keep-spelling boundary, not part of the broader nontrapping-argument exactification/miss predicates
- the OI-J TNH typed-table `call_ref` exact descriptor-success families under semantic preconditions: after call_ref directization, ordered nontrapping leaf operands plus a nontrapping table index feed either a reference-side `call_indirect` whose type returns an exact non-null target reference paired with a direct descriptor call, or a descriptor-side `call_indirect` whose type returns an exact non-null descriptor paired with a direct exact reference call; default and IIT keep the exact descriptor cast, while `--traps-never-happen` preserves source order and drops the descriptor result without the descriptor equality trap
- the adjacent OI-J direct-call descriptor exactification/narrowing family under semantic preconditions: ordered nontrapping `local.get*`, scalar constant (`i32.const`/`i64.const` with the same scanner predicate covering `f32.const`/`f64.const`), `global.get`, or no-parameter direct scalar value-call chunks as ref-call args, direct same-heap non-null ref call, ordered nontrapping `local.get*`, scalar constant, `global.get`, or no-parameter direct scalar value-call chunks as descriptor-call args, direct exact target descriptor call, and source-order-preserving `ref.cast_desc_eq` retention that rebuilds inexact or nullable source casts as non-null exact without skipping the descriptor check
- the OI-J standalone `ref.get_desc` null-check movement family for direct locals, nullable global.get leaves, local.tee chunks fed by nontrapping nullable local/global leaves, branch-free blocks, self-contained branch/cast blocks, escaping direct-`br` and value-`br_table` block children, branch-free select/effect-safe if nullable children, and direct-call and typed-table-call_ref/directized `call_indirect` children with no parameters or nontrapping leaf operands, preserving the nullable child as the `ref.get_desc` operand in default/TNH-focused tests; plus the distinct standalone known-null trap-producing family for direct `ref.null`, `local.tee(ref.null)`, and branch-free blocks ending in `ref.null`, which rewrites to unreachable-producing shapes instead of moving the child under `ref.get_desc`
- dead-region-suffix cleanup with explicit fallback-branch and zero-sentinel preservation

That is a meaningful implemented pass.
But it is not yet the full upstream AST surface.

## Exact local code map

| Surface | Exact code location |
| --- | --- |
| registry descriptor and public summary | `src/passes/optimize.mbt:189-191` |
| hot-preset placement | `src/passes/optimize.mbt:288-303`, `src/passes/optimize.mbt:442-461` |
| hot-pipeline dispatch | `src/passes/pass_manager.mbt:8989` |
| owner file and main entry | `src/passes/optimize_instructions.mbt:2-16`, `src/passes/optimize_instructions.mbt:30-31`, `src/passes/optimize_instructions.mbt:3239-3248` |
| focused reduced-pass tests | `src/passes/optimize_instructions_test.mbt:2`, `src/passes/optimize_instructions_test.mbt:83`, `src/passes/optimize_instructions_test.mbt:135`, `src/passes/optimize_instructions_test.mbt:1338`, `src/passes/optimize_instructions_test.mbt:1971` |
| registry sanity | `src/passes/registry_test.mbt:20`, `src/passes/registry_test.mbt:168`, `src/passes/registry_test.mbt:203-215` |
| CLI replay coverage | `src/cmd/cmd_wbtest.mbt:6720-6755`, `src/cmd/cmd_wbtest.mbt:6765-6864`, `src/cmd/cmd_wbtest.mbt:6870-6908` |

The exact code map is the practical read-along path for the current local implementation.

## What the local pass already models well

### 1. Exact integer and compare peepholes

The local file has dedicated helpers for:

- exact constant folding of binary ops
- constant integer `eq` / `ne` compare folding for direct i32/i64 constant pairs
- unsigned relational constant compare folding for direct i32/i64 `lt_u`, `le_u`, `gt_u`, and `ge_u` constant pairs, signed zero-lhs relational constant coverage, nonnegative-vs-negative signed relational constant fold coverage, signed zero-rhs constant relational keep/canonicalize boundary coverage, plus boundary coverage for Binaryen's mixed signed relational constant-pair behavior including same-sign negative keep-spelling, mixed same-sign nonnegative signed constant fold/canonicalize coverage, and `i64.extend_i32_u` unsigned maxBits producer coverage including narrowed child max fact propagation
- unsigned domain-edge folds for `x <_u 0`, `x >=_u 0`, `x >_u UINT_MAX`, and `x <=_u UINT_MAX`, preserving effectful operands as a drop before the boolean constant; signed domain-edge folds for side-effect-free `x <s INT_MIN`, `x >=s INT_MIN`, `x >s INT_MAX`, and `x <=s INT_MAX`, deliberately keeping call-backed signed endpoints because Binaryen kept the probed effectful shape
- `eqz` rewrites such as subtraction/addition compare lowering, nonliteral direct double-`eqz` to `ne zero` cleanup plus literal double-`eqz` final folding to constants, direct zero-compare `eqz` inversion, integer-relational `eqz(compare)` inversion, float equality/inequality `eqz(compare)` inversion, and the narrow De Morgan `i32.and(i32.eqz X, i32.eqz Y)` to `i32.eqz(i32.or X Y)` boolean cleanup while intentionally preserving literal-constant `eqz` nodes and float relational `eqz(compare)` nodes to match Binaryen's direct pass output; direct i32 boolean constant `select` arms now fold `1/0` to `i32.ne(cond, 0)` and `0/1` to `i32.eqz(cond)`, direct `i32.eqz` select conditions now swap select arms and use the inner condition, and direct `i64.eqz` boolean selects now fold exact i32 `1/0` arms to `i64.eqz(inner)` and `0/1` arms to `i64.ne(inner, 0)`
- compare-to-zero rewrites
- same-local integer compare folding plus direct same-local integer binary folds for `sub`/`xor` to zero and `and`/`or` to the local value
- pure and effect-preserving i32/i64 masked unsigned-compare folding when an `and` with a nonnegative mask proves the value is below an out-of-range constant, first recursive i32/i64 `shr_u` bounded unsigned-compare folds for constant shift amounts `1..31` / `1..63`, carrying direct child `and`/`shr_u` and unsigned-load maxBits facts, and a Binaryen `LocalScanner`-shaped whole-function local fact store for integer locals: non-param integer locals start from default-zero unsigned facts, every `local.set` / `local.tee` merges a conservative unsigned max fact, later wider or unknown writes prevent earlier `local.get` uses from relying on an over-precise straight-line fact, and sign-extension facts likewise merge per local and become unknown on contradictory writes. The same family also covers first nonnegative signed-relational out-of-range folds plus in-range signed-to-unsigned spelling rewrites, dropping effectful masked/shifted/loaded values before the replacement constant when folding, first direct i32 sign-extension equality range folds for `i32.extend8_s` / `i32.extend16_s`, narrow unsigned-top compare rewrites for i32 `extend8_s` / `extend16_s` against `u32::MAX` and i64 `extend8_s` / `extend16_s` / `extend32_s` against `u64::MAX`, and source-backed keep-spelling coverage for the corresponding i64 sign-extension out-of-range equality boundary and direct i32 sign-extension signed-relational boundary
- relational operand canonicalization
- relational-constant normalization

This is the part of the implementation that most closely matches the mental model most readers start with.

### 2. Commutative canonicalization with HOT-specific safety proof

The local file has explicit machinery for:

- moving constants to the preferred side
- sorting local gets and some node kinds conservatively
- refusing reordering across same-local writes, shared tee payloads, trapping loads, and loop-carried inputs

That matches the upstream strategy of canonicalize-first, but the proof substrate is local-HOT-specific. The general commutative canonicalizer is live for ranked HOT value nodes, including call / indirect-call / call_ref value operands, and uses the same sound reorder proof (`optimize_instructions_subtrees_can_swap`) exercised by the leading `(0 - x) + y -> y - x` rewrite (see section 3). Calls rank before locals/constants to match Binaryen's call-first spelling, but memory/table/global/local conflicts and may-trap-past-side-effect hazards still block the swap. The public/raw pipeline now admits the narrow straight-line stack form `pure local.get/const; no-param direct call; commutative integer binop` so simple call-operand fixtures reach this HOT path; broader stack-carried effects still skip.

### 3. Add / sub / mul / shift rewrites

The in-tree HOT pass includes helpers for:

- add/sub normalization
- multiply-by-power-of-two to shift rewrites
- redundant shift-mask removal
- effective-zero shift cleanup
- compare-to-zero reductions

The leading `(0 - x) + y -> y - x` rewrite (i32/i64) reorders the two operands and is therefore gated by the sound `subtrees_can_swap` reorder proof (no RAW/WAR/WAW region conflict, no may-trap/throw past a side effect, no control-flow operands); the trailing `y + (0 - x) -> y - x` needs no guard. The sibling `-x * -y -> x * y` (i32/i64) strips both negations in place, so it needs no reorder proof and applies even for effectful factors such as `(0 - call) * (0 - y)`.

So Starshine already covers a meaningful subset of the arithmetic rewrite surface.

### 4. Memory and stored-value cleanup

The local pass covers the small Binaryen-style memory surface that has direct HOT support: tiny `memory.copy` / `memory.fill` lowering for selected constant sizes, including size-16 `memory.copy` to `v128.load` / `v128.store` and size-16 repeated-byte `memory.fill` to `v128.const` / `v128.store`, source-backed flat stack-carried call coverage for the size-16 copy lane, flat stack-carried tiny `memory.copy` and byte `memory.fill` forms whose operands may independently be local/constant/global operands, no-param direct-call operands, or direct calls with pure local/constant/global arguments, and mixed flat tiny-copy/byte-fill functions when every bulk operation matches the narrow size rules. Dynamic `memory.fill` values now follow Binaryen v130's boundary: only size-1 dynamic fills lower to `store8`; larger size-2/4/8 dynamic local values remain `memory.fill` rather than synthesized repeated-byte multiply trees. It also covers constant-pointer static-offset folding (including the narrow public `i32.const; nonzero-offset scalar load; drop; call` raw-gate escape), narrow-store redundant-mask and constant truncation cleanup, direct `i32.wrap_i64` store widening with source memargs preserved, direct reinterpret-store representation rewrites such as `f32.store(f32.reinterpret_i32 x)` to `i32.store x` with source memargs preserved, one-use full-width reinterpret-load result rewrites such as `f32.reinterpret_i32(i32.load p)` to `f32.load p`, and one-use `i64.extend_i32_*` load-result rewrites such as `i64.extend_i32_u(i32.load p)` to `i64.load32_u p`. The representation-load rewrites preserve the original load memarg offset and alignment.

Broader memory work remains deliberately open or boundary-tested: zero-size bulk-memory cleanup needs trap-relaxed mode support, and the boundary now explicitly covers effectful call operands because Binaryen also keeps zero-size `memory.copy` / `memory.fill` in that shape; dynamic-size `memory.copy` / `memory.fill` with call-backed size operands, nonconstant local size operands, or nonconstant `global.get` size operands are also explicit keep-spelling boundaries rather than exact tiny lowering candidates; non-power-of-two size-3 `memory.copy` / `memory.fill` plus size-5, size-6, size-7, size-9, size-10, size-11, size-12, size-13, size-14, size-15, size-17, size-18, size-19, size-20, size-21, size-22, size-23, size-24, size-25, size-26, size-27, size-28, size-29, size-30, size-31, size-32, size-33, size-34, size-35, size-36, size-37, and size-38 `memory.copy` / `memory.fill` are likewise source-backed keep-spelling boundaries rather than multi-store lowering candidates; non-flat or broader effect/control `memory.copy` localization remains open beyond the covered pure-argument/global-get direct-call address/value subsets and their source-backed mixed combinations, nonconstant-pointer load/drop/call shapes such as `local.get; i32.load offset=4; drop; call` are source-backed keep-spelling boundaries and broader mixed load/call functions still stop at the public raw gate, non-local wider `memory.fill` values such as calls or computed `i32.add` values are source-backed keep-spelling boundaries rather than missing materialization, now including call-backed and local.get-backed size-16 SIMD-width fills that Binaryen keeps as `memory.fill` (size-1 byte fills, including pure-argument direct-call subsets, and constant-value size-16 fills are the covered store/SIMD exceptions), local-carried/shared load-result spellings such as `local.tee(i32.load)` plus reinterpret or extend are source-backed boundaries rather than direct one-use load-result gaps, local-carried/shared reinterpret-store spellings such as `local.tee(f32.reinterpret_i32(...))` or `local.set`/`local.get` before `f32.store` are source-backed boundaries rather than direct one-use stored-value gaps, and local-carried/shared `i32.wrap_i64` values before narrow i32 stores are source-backed keep-spelling boundaries rather than hidden broader store-widening parity.

### 5. Boolean and nested-`if` cleanup

The local file goes fairly deep on HOT-IR boolean and control patterns.
It can:

- optimize `if` conditions directly
- fold constant conditions
- recursively negate nested boolean trees
- fold the direct `i32.and(i32.eqz X, i32.eqz Y)` shell to `i32.eqz(i32.or X Y)` while preserving operand order
- wrap certain boolean value-`if`s in `eqz`
- flip some nested conditions when the tree is unshared
- collapse duplicate then-branch `if`s into a direct branch

### 6. Artifact-backed dead-suffix and fallback-branch cleanup

The current local pass includes logic for:

- truncating dead suffixes after escaping control
- preserving value-carrying fallback branches in mixed-label and nested-return shapes
- keeping explicit zero sentinels when the result carrier still flows to a `drop` or another value-preserving boundary

Those are local HOT-IR and writeback-survival rules, not a literal upstream phase mirror.

### 7. Fact-driven port status

The 2026-07-06 recursive Binaryen-porting track is replacing narrow scanner families with explicit source-backed facts before widening behavior. `src/passes/optimize_instructions.mbt` now has a Binaryen `LocalScanner`-shaped `OptimizeInstructionsLocalFacts` store for integer sign-extension and unsigned max facts, plus the OI-J reference/descriptor/null-trap fact layer: `OiRefFact`, `OiNullTrapFact`, `OiRefProducerFact`, `OiRefTestFact`, `OiRefTestResultFact`, `OiDescriptorTypeFact`, `OiDescriptorOperandFact`, `OiDescriptorCastFact`, `OiDescriptorExactMissFact`, `OiDescriptorTnhSkipFact`, and `OiRefGetDescFact`. Those OI-J facts currently drive direct known-null `ref.get_desc` trapping, known-null `ref.test` / `ref.test_desc` folding, same-heap non-null `ref.test_desc` success folding, known-non-null `ref.is_null` / `ref.as_non_null` decisions, direct/call_indirect/call_ref reference-result heap facts, exact-described-heap descriptor reasoning, two-operand `ref.cast_desc_eq` operand/target facts, exact descriptor-miss drop/unreachable action facts, standalone `ref.get_desc` child/null-check movement facts, descriptor erase/trap decisions, exact-success/exact-miss/narrow/null descriptor-cast routing, and TNH descriptor localization/exactness guards. `OiCallRefTargetFact` now represents direct `ref.func`, table/index, fallthrough-block `ref.func`, and select-of-`ref.func` targets for call_ref/return_call_ref directization, with `OiCallRefOperandFact` owning the scalar argument localization proof those target families need; `OiRefProducerFact` also gives descriptor-cast code a shared call_ref signature/result fact for descriptor-producer reasoning before broader call_ref descriptor-producer parity lands. OI-G now has `OiBulkMemoryFact` for memory.copy/fill operand, dynamic/constant-size, memory-index, trap-relaxed same-address `memory.copy`, and local-backed zero-size bulk drop facts, `OiTinyMemoryCopyFact` for tiny memory.copy size/load/store choices, `OiTinyMemoryFillFact` for Binaryen v130 tiny memory.fill size/value/shrink boundaries, and `OiMemoryAccessFact` / `OiAtomicAccessFact` for load result types, narrow-store value widths, i64 narrow-store classification, and memarg rewriting. OI-M/localization now has `OiTupleLaneFact` and `OiTupleExtractFact` for one-use `tuple.extract(tuple.make(...))` lane/result/effect-order facts, `OiTupleScratchFact` for selected-lane temporary-local planning, plus `OiOrderedOperandFact` for scalar ordered-effect preservation in the forward-selected and ordered-effects helpers. This is intentionally partial: remaining OI-J scanner families around descriptor-test miss/fallthrough-type breadth, nested standalone `ref.get_desc` control/EH shapes, and descriptor-localization control shapes; richer descriptor-producer call_ref facts beyond shared signature/result facts; broader memory/bulk ordering/localization facts beyond the tiny lowering and local-backed trap-relaxed drop facts; broader tuple-scratch/multivalue localization facts beyond the one-use selected-lane scratch fact; and final-repair fact families are still active backlog work.

## What upstream Binaryen still does that Starshine lacks

The local pass does not yet model the upstream visitor families for:

- broad reference-typed and GC rewrites beyond the many narrow OI-I/OI-J/OI-K subsets already covered; OI-J now covers direct-call exact descriptor misses with ordered nontrapping local/scalar-constant/global arguments, pure-reference/direct-descriptor-call exact descriptor misses with ordered nontrapping local/scalar-constant/global descriptor arguments plus branch-free value-block, no-parameter direct value-call, parameterized direct value-call descriptor-call arguments with ordered nontrapping leaf operands, no-parameter direct non-null reference-result descriptor-call arguments, parameterized direct non-null reference-result descriptor-call arguments with nontrapping leaf operands, scalar-producer local.tee descriptor-call arguments, pure nontrapping-leaf select descriptor-call arguments, stack-form trapping integer div/rem scalar descriptor-call arguments with nontrapping leaves, and exact `ref.func` + `call_ref` descriptor producers, pure-local direct-call exact descriptor successes plus a Binaryen-backed keep-spelling boundary for scalar-constant/global exact-success direct-call arguments, typed-table call_ref reference-producer exact descriptor successes and descriptor-producer exact-successes under TNH after directization to call_indirect, typed-table call_ref descriptor-producer strict-subtype misses directized to call_indirect, same-heap direct-call descriptor exactification/narrowing with ordered nontrapping local/scalar-constant/global arguments, standalone `ref.get_desc` null-check movement through direct local, nullable global.get, local.tee(local.get/global.get), branch-free block, self-contained branch/cast block, escaping direct-`br` and value-`br_table` block children, branch-free select, effect-safe if, no-parameter/leaf-operand direct-call nullable children, and typed-table call_ref children directized to call_indirect with nontrapping leaf operands, and the distinct standalone `ref.get_desc` known-null trap-producing family for direct `ref.null`, `local.tee(ref.null)`, and branch-free blocks ending in `ref.null`, as semantic families rather than arity whitelists; nullable/inexact descriptor success/skip breadth outside that narrowing shape, broader `ref.get_desc` localization beyond those child families, TNH/IIT mode breadth, broader effectful/trapping call arguments beyond the covered nontrapping leaves, branch-free descriptor-call block arguments, no-parameter direct value calls, parameterized direct value calls with nontrapping leaf operands, no-parameter/parameterized non-null reference-result direct calls, scalar-producer local.tee value arguments, pure nontrapping-leaf select value arguments, stack-form integer div/rem chunks, no-parameter scalar value-call arguments in exactification/narrowing, broader call_ref descriptor-producer shapes beyond the covered exact ref.func descriptor-producer, typed-table descriptor-miss, and typed-table TNH exact-success reference/descriptor-producer subsets, indirect/return_call* and multivalue producers, broader escaping `br_on_*` and nested control/EH descriptor operands, descriptor-test miss/fallthrough-type parity beyond known-null and same-heap success fact folds, and descriptor BrOn representation/tooling remain open; the OI-K default-array get subset now keeps negative and huge `array.new_default` lengths to preserve allocation traps before folding constant-index gets
- GC aggregate RMW/cmpxchg lowering: Starshine exposes `struct.atomic.get*` but not aggregate RMW/cmpxchg text/core constructors, while Binaryen optimizes source-backed non-mutating RMW/cmpxchg forms to `struct.get`-like reads
- `call_ref` directization facts beyond the covered direct/ref.func, constant-index and call-indexed table.get, select, and fallthrough-known subsets with zero arguments or localized single-result arguments; the current target and scalar-operand facts cover those subsets, and `OiRefProducerFact` now gives descriptor-cast logic a shared call_ref signature/result fact, while richer descriptor-producer target/operand facts, broader argument-order, fallthrough type-lattice, and multi-result argument select-of-`ref.func` directization remain open (the multi-result case is a documented tuple-scratch localization boundary for both `call_ref` and `return_call_ref`)
- broader memory and bulk-memory lowering beyond the covered tiny-copy/fill, stored-value, load-result, offset-fold, trap-relaxed same-local `memory.copy`, local-backed zero-size bulk drops, and narrow raw-gate escapes; tiny copy/fill and the first trap-relaxed cleanup decisions now start from `OiBulkMemoryFact`, but broader bulk-memory ordering/localization, stack-carried zero-size call operands, multi-store materialization, and effect/control operand movement are still open
- tuple extraction parity beyond the one-use tuple.make subset with pure siblings or covered selected trapping lanes (including earlier/later, two-later, two-earlier, and two-earlier-plus-one/two/three/four/five/six/seven/eight-later effectful sibling coverage) and single-result effectful/trapping sibling drop/localization; the covered one-use subset now routes through explicit `OiTupleLaneFact` / `OiTupleExtractFact` lane facts, `OiTupleScratchFact` selected-lane temporary-local facts, and shared `OiOrderedOperandFact` scalar effect-order facts instead of the old open-coded tuple scanner, but full `simplify-locals` and dedicated `tuple-optimization` on public multivalue-block probes, including effect-count ladder coverage through ninety-seven later non-selected effects for `tuple-optimization` variants, are documented boundaries because Binaryen uses tuple scratch and Starshine keeps the block/drop spelling, direct-HOT replay of the full-simplify shape currently hits `InvalidChildRef`, local-carried / multi-use tuple extraction is a documented keep-spelling boundary for the probed Binaryen `version_130` shape, and multi-result non-selected siblings (including the earlier-sibling variant) plus multi-result selected children, including the selected-second, selected-third, selected-fourth, selected-fifth, selected-sixth, selected-seventh, selected-eighth, selected-ninth, selected-tenth, selected-eleventh, selected-twelfth, selected-thirteenth, and selected-fourteenth lanes, remain broader tuple-scratch localization boundaries, while the direct no-sibling selected-fifteenth, selected-sixteenth, selected-seventeenth, selected-eighteenth, and selected-nineteenth call shapes are source-backed keep-spelling boundaries
- a complete whole-function local prescan equivalent beyond the current Binaryen-shaped integer local fact store: Starshine now has per-local sign-extension and unsigned-max facts for direct/local-carried sign and maxBits folds, but still lacks full upstream `Bits::getMaxBits` breadth over arbitrary fallthrough expressions, more precise helper-backed local facts for newer locals added after scanning, and the rest of Binaryen's source-level helper lattice. Direct, `i32.wrap_i64`, and `i64.extend_i32_u` maxBits compare folds/spelling rewrites including narrowed child facts, direct sign-extension equality range folds, and source-backed sign-extension relational plus i32/i64 dynamic-shift maxBits keep-spelling boundaries remain the documented covered/boundary subset rather than full LocalScanner parity.
- deferred `ReFinalize` / EH-pop repair inside this pass

The 2026-06-19 `version_130` matrix routes those gaps to `[O4Z-AUDIT-OI-D]` through `[O4Z-AUDIT-OI-M]`, with `[O4Z-AUDIT-OI-N]` reserved for final direct/O4z closeout. That gap is intentional and documented so readers do not mistake the current local pass for a full upstream port.

## How to read this with the rest of the folder

- [`./index.md`](./index.md) explains the overall pass role and page map.
- [`./binaryen-strategy.md`](./binaryen-strategy.md) explains the upstream Binaryen contract.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) maps the owning files and proof surfaces.
- [`./gc-casts-call_ref-and-trap-sensitive-rewrites.md`](./gc-casts-call_ref-and-trap-sensitive-rewrites.md) covers the upstream reference-typed half that the current local pass does not model.
- [`./wat-shapes.md`](./wat-shapes.md) gives the beginner-friendly shape catalog.
- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md) is the exact MoonBit helper/code-map companion.

## Validation guidance

The current local evidence surface is:

- focused WAT tests for the exact families listed above,
- registry and explicit-pass CLI tests proving `optimize-instructions` remains active,
- repeated-pass replay coverage on the debug artifact and ordered generated-artifact predecessors, and
- pass-targeted fuzz comparison when the implementation changes.

That is enough to keep the current HOT subset honest while preserving the distinction between local reality and upstream Binaryen's wider pass contract.
