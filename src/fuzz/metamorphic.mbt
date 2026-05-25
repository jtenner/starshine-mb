///|
pub enum MetamorphicValidTransform {
  AddNonNameCustomSection
  AddLeadingNonNameCustomSection
  AddCustomSectionStress
  AddModuleNameSection
  AddUnusedPassiveDataSegment
  AddUnusedImmutableI32Global
  AddUnusedEmptyFunction
  AddUnusedEmptyFunctionType
  AddDuplicateEquivalentFunctionType
  AddUnusedFuncrefTable
  AddUnusedPassiveFuncrefElementSegment
  AddFunctionNamesSection
  AddLocalNamesSection
  AddLabelNamesSection
  AddTypeNamesSection
  AddGlobalNamesSection
  AddTableNamesSection
  AddMemoryNamesSection
  AddDataNamesSection
  AddElemNamesSection
  AddTagNamesSection
  AddFieldNamesSection
  AddUnusedI32LocalToDefinedFunctions
  AddUnusedNumericLocalsToDefinedFunctions
  AddUnusedReferenceLocalsToDefinedFunctions
  AddUnusedV128LocalToDefinedFunctions
  AddUnusedGcReferenceLocalsToDefinedFunctions
  AddLeadingRefNullDropToDefinedFunctions
  AddTrailingRefNullDropToDefinedFunctions
  AddLeadingI64ConstDropToDefinedFunctions
  AddTrailingI64ConstDropToDefinedFunctions
  AddLeadingF32ConstDropToDefinedFunctions
  AddTrailingF32ConstDropToDefinedFunctions
  AddLeadingF64ConstDropToDefinedFunctions
  AddTrailingF64ConstDropToDefinedFunctions
  AddLeadingFalseIfToDefinedFunctions
  AddTrailingFalseIfToDefinedFunctions
  AddLeadingTrueIfToDefinedFunctions
  AddTrailingTrueIfToDefinedFunctions
  AddLeadingI32EqzDropToDefinedFunctions
  AddTrailingI32EqzDropToDefinedFunctions
  AddLeadingI64EqzDropToDefinedFunctions
  AddTrailingI64EqzDropToDefinedFunctions
  AddLeadingI32EqDropToDefinedFunctions
  AddTrailingI32EqDropToDefinedFunctions
  AddLeadingI32NeDropToDefinedFunctions
  AddTrailingI32NeDropToDefinedFunctions
  AddLeadingI64EqDropToDefinedFunctions
  AddTrailingI64EqDropToDefinedFunctions
  AddLeadingI64NeDropToDefinedFunctions
  AddTrailingI64NeDropToDefinedFunctions
  AddLeadingI32LtSDropToDefinedFunctions
  AddTrailingI32LtSDropToDefinedFunctions
  AddLeadingI32GtSDropToDefinedFunctions
  AddTrailingI32GtSDropToDefinedFunctions
  AddLeadingI64LtSDropToDefinedFunctions
  AddTrailingI64LtSDropToDefinedFunctions
  AddLeadingI64GtSDropToDefinedFunctions
  AddTrailingI64GtSDropToDefinedFunctions
  AddLeadingI32LeSDropToDefinedFunctions
  AddTrailingI32LeSDropToDefinedFunctions
  AddLeadingI32GeSDropToDefinedFunctions
  AddTrailingI32GeSDropToDefinedFunctions
  AddLeadingI64LeSDropToDefinedFunctions
  AddTrailingI64LeSDropToDefinedFunctions
  AddLeadingI64GeSDropToDefinedFunctions
  AddTrailingI64GeSDropToDefinedFunctions
  AddLeadingI32LtUDropToDefinedFunctions
  AddTrailingI32LtUDropToDefinedFunctions
  AddLeadingI32GtUDropToDefinedFunctions
  AddTrailingI32GtUDropToDefinedFunctions
  AddLeadingI64LtUDropToDefinedFunctions
  AddTrailingI64LtUDropToDefinedFunctions
  AddLeadingI64GtUDropToDefinedFunctions
  AddTrailingI64GtUDropToDefinedFunctions
  AddLeadingI32LeUDropToDefinedFunctions
  AddTrailingI32LeUDropToDefinedFunctions
  AddLeadingI32GeUDropToDefinedFunctions
  AddTrailingI32GeUDropToDefinedFunctions
  AddLeadingI64LeUDropToDefinedFunctions
  AddTrailingI64LeUDropToDefinedFunctions
  AddLeadingI64GeUDropToDefinedFunctions
  AddTrailingI64GeUDropToDefinedFunctions
  AddLeadingI32AndDropToDefinedFunctions
  AddTrailingI32AndDropToDefinedFunctions
  AddLeadingI32OrDropToDefinedFunctions
  AddTrailingI32OrDropToDefinedFunctions
  AddLeadingI32XorDropToDefinedFunctions
  AddTrailingI32XorDropToDefinedFunctions
  AddLeadingI64AndDropToDefinedFunctions
  AddTrailingI64AndDropToDefinedFunctions
  AddLeadingI64OrDropToDefinedFunctions
  AddTrailingI64OrDropToDefinedFunctions
  AddLeadingI64XorDropToDefinedFunctions
  AddTrailingI64XorDropToDefinedFunctions
  AddLeadingI32ClzDropToDefinedFunctions
  AddTrailingI32ClzDropToDefinedFunctions
  AddLeadingI32CtzDropToDefinedFunctions
  AddTrailingI32CtzDropToDefinedFunctions
  AddLeadingI32PopcntDropToDefinedFunctions
  AddTrailingI32PopcntDropToDefinedFunctions
  AddLeadingI64ClzDropToDefinedFunctions
  AddTrailingI64ClzDropToDefinedFunctions
  AddLeadingI64CtzDropToDefinedFunctions
  AddTrailingI64CtzDropToDefinedFunctions
  AddLeadingI64PopcntDropToDefinedFunctions
  AddTrailingI64PopcntDropToDefinedFunctions
  AddLeadingI32WrapI64DropToDefinedFunctions
  AddTrailingI32WrapI64DropToDefinedFunctions
  AddLeadingI64ExtendI32SDropToDefinedFunctions
  AddTrailingI64ExtendI32SDropToDefinedFunctions
  AddLeadingI64ExtendI32UDropToDefinedFunctions
  AddTrailingI64ExtendI32UDropToDefinedFunctions
  AddLeadingF32ConvertI32SDropToDefinedFunctions
  AddTrailingF32ConvertI32SDropToDefinedFunctions
  AddLeadingF32ConvertI32UDropToDefinedFunctions
  AddTrailingF32ConvertI32UDropToDefinedFunctions
  AddLeadingF32ConvertI64SDropToDefinedFunctions
  AddTrailingF32ConvertI64SDropToDefinedFunctions
  AddLeadingF32ConvertI64UDropToDefinedFunctions
  AddTrailingF32ConvertI64UDropToDefinedFunctions
  AddLeadingI32ShlDropToDefinedFunctions
  AddTrailingI32ShlDropToDefinedFunctions
  AddLeadingI32ShrSDropToDefinedFunctions
  AddTrailingI32ShrSDropToDefinedFunctions
  AddLeadingI32ShrUDropToDefinedFunctions
  AddTrailingI32ShrUDropToDefinedFunctions
  AddLeadingI64ShlDropToDefinedFunctions
  AddTrailingI64ShlDropToDefinedFunctions
  AddLeadingI64ShrSDropToDefinedFunctions
  AddTrailingI64ShrSDropToDefinedFunctions
  AddLeadingI64ShrUDropToDefinedFunctions
  AddTrailingI64ShrUDropToDefinedFunctions
  AddLeadingI32RotlDropToDefinedFunctions
  AddTrailingI32RotlDropToDefinedFunctions
  AddLeadingI32RotrDropToDefinedFunctions
  AddTrailingI32RotrDropToDefinedFunctions
  AddLeadingI64RotlDropToDefinedFunctions
  AddTrailingI64RotlDropToDefinedFunctions
  AddLeadingI64RotrDropToDefinedFunctions
  AddTrailingI64RotrDropToDefinedFunctions
  AddLeadingF32AbsDropToDefinedFunctions
  AddTrailingF32AbsDropToDefinedFunctions
  AddLeadingF64AbsDropToDefinedFunctions
  AddTrailingF64AbsDropToDefinedFunctions
  AddLeadingF32NegDropToDefinedFunctions
  AddTrailingF32NegDropToDefinedFunctions
  AddLeadingF64NegDropToDefinedFunctions
  AddTrailingF64NegDropToDefinedFunctions
  AddLeadingF32SqrtDropToDefinedFunctions
  AddTrailingF32SqrtDropToDefinedFunctions
  AddLeadingF64SqrtDropToDefinedFunctions
  AddTrailingF64SqrtDropToDefinedFunctions
  AddLeadingF32CeilDropToDefinedFunctions
  AddTrailingF32CeilDropToDefinedFunctions
  AddLeadingF32FloorDropToDefinedFunctions
  AddTrailingF32FloorDropToDefinedFunctions
  AddLeadingF64CeilDropToDefinedFunctions
  AddTrailingF64CeilDropToDefinedFunctions
  AddLeadingF64FloorDropToDefinedFunctions
  AddTrailingF64FloorDropToDefinedFunctions
  AddLeadingF32TruncDropToDefinedFunctions
  AddTrailingF32TruncDropToDefinedFunctions
  AddLeadingF32NearestDropToDefinedFunctions
  AddTrailingF32NearestDropToDefinedFunctions
  AddLeadingF64TruncDropToDefinedFunctions
  AddTrailingF64TruncDropToDefinedFunctions
  AddLeadingF64NearestDropToDefinedFunctions
  AddTrailingF64NearestDropToDefinedFunctions
  AddLeadingF32AddDropToDefinedFunctions
  AddTrailingF32AddDropToDefinedFunctions
  AddLeadingF32SubDropToDefinedFunctions
  AddTrailingF32SubDropToDefinedFunctions
  AddLeadingF64AddDropToDefinedFunctions
  AddTrailingF64AddDropToDefinedFunctions
  AddLeadingF64SubDropToDefinedFunctions
  AddTrailingF64SubDropToDefinedFunctions
  AddLeadingF32MulDropToDefinedFunctions
  AddTrailingF32MulDropToDefinedFunctions
  AddLeadingF32DivDropToDefinedFunctions
  AddTrailingF32DivDropToDefinedFunctions
  AddLeadingF64MulDropToDefinedFunctions
  AddTrailingF64MulDropToDefinedFunctions
  AddLeadingF64DivDropToDefinedFunctions
  AddTrailingF64DivDropToDefinedFunctions
  AddLeadingF32MinDropToDefinedFunctions
  AddTrailingF32MinDropToDefinedFunctions
  AddLeadingF32MaxDropToDefinedFunctions
  AddTrailingF32MaxDropToDefinedFunctions
  AddLeadingF64MinDropToDefinedFunctions
  AddTrailingF64MinDropToDefinedFunctions
  AddLeadingF64MaxDropToDefinedFunctions
  AddTrailingF64MaxDropToDefinedFunctions
  AddLeadingF32CopysignDropToDefinedFunctions
  AddTrailingF32CopysignDropToDefinedFunctions
  AddLeadingF64CopysignDropToDefinedFunctions
  AddTrailingF64CopysignDropToDefinedFunctions
  AddLeadingF32EqDropToDefinedFunctions
  AddTrailingF32EqDropToDefinedFunctions
  AddLeadingF32NeDropToDefinedFunctions
  AddTrailingF32NeDropToDefinedFunctions
  AddLeadingF64EqDropToDefinedFunctions
  AddTrailingF64EqDropToDefinedFunctions
  AddLeadingF64NeDropToDefinedFunctions
  AddTrailingF64NeDropToDefinedFunctions
  AddLeadingF32LtDropToDefinedFunctions
  AddTrailingF32LtDropToDefinedFunctions
  AddLeadingF32GtDropToDefinedFunctions
  AddTrailingF32GtDropToDefinedFunctions
  AddLeadingF64LtDropToDefinedFunctions
  AddTrailingF64LtDropToDefinedFunctions
  AddLeadingF64GtDropToDefinedFunctions
  AddTrailingF64GtDropToDefinedFunctions
  AddLeadingF32LeDropToDefinedFunctions
  AddTrailingF32LeDropToDefinedFunctions
  AddLeadingF32GeDropToDefinedFunctions
  AddTrailingF32GeDropToDefinedFunctions
  AddLeadingF64LeDropToDefinedFunctions
  AddTrailingF64LeDropToDefinedFunctions
  AddLeadingF64GeDropToDefinedFunctions
  AddTrailingF64GeDropToDefinedFunctions
  AddLeadingNopToDefinedFunctions
  AddTrailingNopToDefinedFunctions
  AddLeadingI32ConstDropToDefinedFunctions
  AddTrailingI32ConstDropToDefinedFunctions
  AddTrailingEmptyVoidBlockToDefinedFunctions
  AddLeadingEmptyVoidBlockToDefinedFunctions
  AddLeadingEmptyVoidLoopToDefinedFunctions
  SplitMergeLocalDeclarations
  AddTrailingEmptyVoidLoopToDefinedFunctions
  WrapDefinedFunctionBodiesInIdentityBlock
  AddExportAliases
  AddPrefixedExportAliases
  AddSuffixedExportAliases
  ReverseCustomSections
} derive(Eq, Debug)

///|
pub fn metamorphic_valid_transform_id(
  transform : MetamorphicValidTransform,
) -> String {
  match transform {
    AddNonNameCustomSection => "add-non-name-custom-section"
    AddLeadingNonNameCustomSection => "add-leading-non-name-custom-section"
    AddCustomSectionStress => "add-custom-section-stress"
    AddModuleNameSection => "add-module-name-section"
    AddUnusedPassiveDataSegment => "add-unused-passive-data-segment"
    AddUnusedImmutableI32Global => "add-unused-immutable-i32-global"
    AddUnusedEmptyFunction => "add-unused-empty-function"
    AddUnusedEmptyFunctionType => "add-unused-empty-function-type"
    AddDuplicateEquivalentFunctionType =>
      "add-duplicate-equivalent-function-type"
    AddUnusedFuncrefTable => "add-unused-funcref-table"
    AddUnusedPassiveFuncrefElementSegment =>
      "add-unused-passive-funcref-element-segment"
    AddFunctionNamesSection => "add-function-names-section"
    AddLocalNamesSection => "add-local-names-section"
    AddLabelNamesSection => "add-label-names-section"
    AddTypeNamesSection => "add-type-names-section"
    AddGlobalNamesSection => "add-global-names-section"
    AddTableNamesSection => "add-table-names-section"
    AddMemoryNamesSection => "add-memory-names-section"
    AddDataNamesSection => "add-data-names-section"
    AddElemNamesSection => "add-elem-names-section"
    AddTagNamesSection => "add-tag-names-section"
    AddFieldNamesSection => "add-field-names-section"
    AddUnusedI32LocalToDefinedFunctions =>
      "add-unused-i32-local-to-defined-functions"
    AddUnusedNumericLocalsToDefinedFunctions =>
      "add-unused-numeric-locals-to-defined-functions"
    AddUnusedReferenceLocalsToDefinedFunctions =>
      "add-unused-reference-locals-to-defined-functions"
    AddUnusedV128LocalToDefinedFunctions =>
      "add-unused-v128-local-to-defined-functions"
    AddUnusedGcReferenceLocalsToDefinedFunctions =>
      "add-unused-gc-reference-locals-to-defined-functions"
    AddLeadingRefNullDropToDefinedFunctions =>
      "add-leading-ref-null-drop-to-defined-functions"
    AddTrailingRefNullDropToDefinedFunctions =>
      "add-trailing-ref-null-drop-to-defined-functions"
    AddLeadingI64ConstDropToDefinedFunctions =>
      "add-leading-i64-const-drop-to-defined-functions"
    AddTrailingI64ConstDropToDefinedFunctions =>
      "add-trailing-i64-const-drop-to-defined-functions"
    AddLeadingF32ConstDropToDefinedFunctions =>
      "add-leading-f32-const-drop-to-defined-functions"
    AddTrailingF32ConstDropToDefinedFunctions =>
      "add-trailing-f32-const-drop-to-defined-functions"
    AddLeadingF64ConstDropToDefinedFunctions =>
      "add-leading-f64-const-drop-to-defined-functions"
    AddTrailingF64ConstDropToDefinedFunctions =>
      "add-trailing-f64-const-drop-to-defined-functions"
    AddLeadingFalseIfToDefinedFunctions =>
      "add-leading-false-if-to-defined-functions"
    AddTrailingFalseIfToDefinedFunctions =>
      "add-trailing-false-if-to-defined-functions"
    AddLeadingTrueIfToDefinedFunctions =>
      "add-leading-true-if-to-defined-functions"
    AddTrailingTrueIfToDefinedFunctions =>
      "add-trailing-true-if-to-defined-functions"
    AddLeadingI32EqzDropToDefinedFunctions =>
      "add-leading-i32-eqz-drop-to-defined-functions"
    AddTrailingI32EqzDropToDefinedFunctions =>
      "add-trailing-i32-eqz-drop-to-defined-functions"
    AddLeadingI64EqzDropToDefinedFunctions =>
      "add-leading-i64-eqz-drop-to-defined-functions"
    AddTrailingI64EqzDropToDefinedFunctions =>
      "add-trailing-i64-eqz-drop-to-defined-functions"
    AddLeadingI32EqDropToDefinedFunctions =>
      "add-leading-i32-eq-drop-to-defined-functions"
    AddTrailingI32EqDropToDefinedFunctions =>
      "add-trailing-i32-eq-drop-to-defined-functions"
    AddLeadingI32NeDropToDefinedFunctions =>
      "add-leading-i32-ne-drop-to-defined-functions"
    AddTrailingI32NeDropToDefinedFunctions =>
      "add-trailing-i32-ne-drop-to-defined-functions"
    AddLeadingI64EqDropToDefinedFunctions =>
      "add-leading-i64-eq-drop-to-defined-functions"
    AddTrailingI64EqDropToDefinedFunctions =>
      "add-trailing-i64-eq-drop-to-defined-functions"
    AddLeadingI64NeDropToDefinedFunctions =>
      "add-leading-i64-ne-drop-to-defined-functions"
    AddTrailingI64NeDropToDefinedFunctions =>
      "add-trailing-i64-ne-drop-to-defined-functions"
    AddLeadingI32LtSDropToDefinedFunctions =>
      "add-leading-i32-lt-s-drop-to-defined-functions"
    AddTrailingI32LtSDropToDefinedFunctions =>
      "add-trailing-i32-lt-s-drop-to-defined-functions"
    AddLeadingI32GtSDropToDefinedFunctions =>
      "add-leading-i32-gt-s-drop-to-defined-functions"
    AddTrailingI32GtSDropToDefinedFunctions =>
      "add-trailing-i32-gt-s-drop-to-defined-functions"
    AddLeadingI64LtSDropToDefinedFunctions =>
      "add-leading-i64-lt-s-drop-to-defined-functions"
    AddTrailingI64LtSDropToDefinedFunctions =>
      "add-trailing-i64-lt-s-drop-to-defined-functions"
    AddLeadingI64GtSDropToDefinedFunctions =>
      "add-leading-i64-gt-s-drop-to-defined-functions"
    AddTrailingI64GtSDropToDefinedFunctions =>
      "add-trailing-i64-gt-s-drop-to-defined-functions"
    AddLeadingI32LeSDropToDefinedFunctions =>
      "add-leading-i32-le-s-drop-to-defined-functions"
    AddTrailingI32LeSDropToDefinedFunctions =>
      "add-trailing-i32-le-s-drop-to-defined-functions"
    AddLeadingI32GeSDropToDefinedFunctions =>
      "add-leading-i32-ge-s-drop-to-defined-functions"
    AddTrailingI32GeSDropToDefinedFunctions =>
      "add-trailing-i32-ge-s-drop-to-defined-functions"
    AddLeadingI64LeSDropToDefinedFunctions =>
      "add-leading-i64-le-s-drop-to-defined-functions"
    AddTrailingI64LeSDropToDefinedFunctions =>
      "add-trailing-i64-le-s-drop-to-defined-functions"
    AddLeadingI64GeSDropToDefinedFunctions =>
      "add-leading-i64-ge-s-drop-to-defined-functions"
    AddTrailingI64GeSDropToDefinedFunctions =>
      "add-trailing-i64-ge-s-drop-to-defined-functions"
    AddLeadingI32LtUDropToDefinedFunctions =>
      "add-leading-i32-lt-u-drop-to-defined-functions"
    AddTrailingI32LtUDropToDefinedFunctions =>
      "add-trailing-i32-lt-u-drop-to-defined-functions"
    AddLeadingI32GtUDropToDefinedFunctions =>
      "add-leading-i32-gt-u-drop-to-defined-functions"
    AddTrailingI32GtUDropToDefinedFunctions =>
      "add-trailing-i32-gt-u-drop-to-defined-functions"
    AddLeadingI64LtUDropToDefinedFunctions =>
      "add-leading-i64-lt-u-drop-to-defined-functions"
    AddTrailingI64LtUDropToDefinedFunctions =>
      "add-trailing-i64-lt-u-drop-to-defined-functions"
    AddLeadingI64GtUDropToDefinedFunctions =>
      "add-leading-i64-gt-u-drop-to-defined-functions"
    AddTrailingI64GtUDropToDefinedFunctions =>
      "add-trailing-i64-gt-u-drop-to-defined-functions"
    AddLeadingI32LeUDropToDefinedFunctions =>
      "add-leading-i32-le-u-drop-to-defined-functions"
    AddTrailingI32LeUDropToDefinedFunctions =>
      "add-trailing-i32-le-u-drop-to-defined-functions"
    AddLeadingI32GeUDropToDefinedFunctions =>
      "add-leading-i32-ge-u-drop-to-defined-functions"
    AddTrailingI32GeUDropToDefinedFunctions =>
      "add-trailing-i32-ge-u-drop-to-defined-functions"
    AddLeadingI64LeUDropToDefinedFunctions =>
      "add-leading-i64-le-u-drop-to-defined-functions"
    AddTrailingI64LeUDropToDefinedFunctions =>
      "add-trailing-i64-le-u-drop-to-defined-functions"
    AddLeadingI64GeUDropToDefinedFunctions =>
      "add-leading-i64-ge-u-drop-to-defined-functions"
    AddTrailingI64GeUDropToDefinedFunctions =>
      "add-trailing-i64-ge-u-drop-to-defined-functions"
    AddLeadingI32AndDropToDefinedFunctions =>
      "add-leading-i32-and-drop-to-defined-functions"
    AddTrailingI32AndDropToDefinedFunctions =>
      "add-trailing-i32-and-drop-to-defined-functions"
    AddLeadingI32OrDropToDefinedFunctions =>
      "add-leading-i32-or-drop-to-defined-functions"
    AddTrailingI32OrDropToDefinedFunctions =>
      "add-trailing-i32-or-drop-to-defined-functions"
    AddLeadingI32XorDropToDefinedFunctions =>
      "add-leading-i32-xor-drop-to-defined-functions"
    AddTrailingI32XorDropToDefinedFunctions =>
      "add-trailing-i32-xor-drop-to-defined-functions"
    AddLeadingI64AndDropToDefinedFunctions =>
      "add-leading-i64-and-drop-to-defined-functions"
    AddTrailingI64AndDropToDefinedFunctions =>
      "add-trailing-i64-and-drop-to-defined-functions"
    AddLeadingI64OrDropToDefinedFunctions =>
      "add-leading-i64-or-drop-to-defined-functions"
    AddTrailingI64OrDropToDefinedFunctions =>
      "add-trailing-i64-or-drop-to-defined-functions"
    AddLeadingI64XorDropToDefinedFunctions =>
      "add-leading-i64-xor-drop-to-defined-functions"
    AddTrailingI64XorDropToDefinedFunctions =>
      "add-trailing-i64-xor-drop-to-defined-functions"
    AddLeadingI32ClzDropToDefinedFunctions =>
      "add-leading-i32-clz-drop-to-defined-functions"
    AddTrailingI32ClzDropToDefinedFunctions =>
      "add-trailing-i32-clz-drop-to-defined-functions"
    AddLeadingI32CtzDropToDefinedFunctions =>
      "add-leading-i32-ctz-drop-to-defined-functions"
    AddTrailingI32CtzDropToDefinedFunctions =>
      "add-trailing-i32-ctz-drop-to-defined-functions"
    AddLeadingI32PopcntDropToDefinedFunctions =>
      "add-leading-i32-popcnt-drop-to-defined-functions"
    AddTrailingI32PopcntDropToDefinedFunctions =>
      "add-trailing-i32-popcnt-drop-to-defined-functions"
    AddLeadingI64ClzDropToDefinedFunctions =>
      "add-leading-i64-clz-drop-to-defined-functions"
    AddTrailingI64ClzDropToDefinedFunctions =>
      "add-trailing-i64-clz-drop-to-defined-functions"
    AddLeadingI64CtzDropToDefinedFunctions =>
      "add-leading-i64-ctz-drop-to-defined-functions"
    AddTrailingI64CtzDropToDefinedFunctions =>
      "add-trailing-i64-ctz-drop-to-defined-functions"
    AddLeadingI64PopcntDropToDefinedFunctions =>
      "add-leading-i64-popcnt-drop-to-defined-functions"
    AddTrailingI64PopcntDropToDefinedFunctions =>
      "add-trailing-i64-popcnt-drop-to-defined-functions"
    AddLeadingI32WrapI64DropToDefinedFunctions =>
      "add-leading-i32-wrap-i64-drop-to-defined-functions"
    AddTrailingI32WrapI64DropToDefinedFunctions =>
      "add-trailing-i32-wrap-i64-drop-to-defined-functions"
    AddLeadingI64ExtendI32SDropToDefinedFunctions =>
      "add-leading-i64-extend-i32-s-drop-to-defined-functions"
    AddTrailingI64ExtendI32SDropToDefinedFunctions =>
      "add-trailing-i64-extend-i32-s-drop-to-defined-functions"
    AddLeadingI64ExtendI32UDropToDefinedFunctions =>
      "add-leading-i64-extend-i32-u-drop-to-defined-functions"
    AddTrailingI64ExtendI32UDropToDefinedFunctions =>
      "add-trailing-i64-extend-i32-u-drop-to-defined-functions"
    AddLeadingF32ConvertI32SDropToDefinedFunctions =>
      "add-leading-f32-convert-i32-s-drop-to-defined-functions"
    AddTrailingF32ConvertI32SDropToDefinedFunctions =>
      "add-trailing-f32-convert-i32-s-drop-to-defined-functions"
    AddLeadingF32ConvertI32UDropToDefinedFunctions =>
      "add-leading-f32-convert-i32-u-drop-to-defined-functions"
    AddTrailingF32ConvertI32UDropToDefinedFunctions =>
      "add-trailing-f32-convert-i32-u-drop-to-defined-functions"
    AddLeadingF32ConvertI64SDropToDefinedFunctions =>
      "add-leading-f32-convert-i64-s-drop-to-defined-functions"
    AddTrailingF32ConvertI64SDropToDefinedFunctions =>
      "add-trailing-f32-convert-i64-s-drop-to-defined-functions"
    AddLeadingF32ConvertI64UDropToDefinedFunctions =>
      "add-leading-f32-convert-i64-u-drop-to-defined-functions"
    AddTrailingF32ConvertI64UDropToDefinedFunctions =>
      "add-trailing-f32-convert-i64-u-drop-to-defined-functions"
    AddLeadingI32ShlDropToDefinedFunctions =>
      "add-leading-i32-shl-drop-to-defined-functions"
    AddTrailingI32ShlDropToDefinedFunctions =>
      "add-trailing-i32-shl-drop-to-defined-functions"
    AddLeadingI32ShrSDropToDefinedFunctions =>
      "add-leading-i32-shr-s-drop-to-defined-functions"
    AddTrailingI32ShrSDropToDefinedFunctions =>
      "add-trailing-i32-shr-s-drop-to-defined-functions"
    AddLeadingI32ShrUDropToDefinedFunctions =>
      "add-leading-i32-shr-u-drop-to-defined-functions"
    AddTrailingI32ShrUDropToDefinedFunctions =>
      "add-trailing-i32-shr-u-drop-to-defined-functions"
    AddLeadingI64ShlDropToDefinedFunctions =>
      "add-leading-i64-shl-drop-to-defined-functions"
    AddTrailingI64ShlDropToDefinedFunctions =>
      "add-trailing-i64-shl-drop-to-defined-functions"
    AddLeadingI64ShrSDropToDefinedFunctions =>
      "add-leading-i64-shr-s-drop-to-defined-functions"
    AddTrailingI64ShrSDropToDefinedFunctions =>
      "add-trailing-i64-shr-s-drop-to-defined-functions"
    AddLeadingI64ShrUDropToDefinedFunctions =>
      "add-leading-i64-shr-u-drop-to-defined-functions"
    AddTrailingI64ShrUDropToDefinedFunctions =>
      "add-trailing-i64-shr-u-drop-to-defined-functions"
    AddLeadingI32RotlDropToDefinedFunctions =>
      "add-leading-i32-rotl-drop-to-defined-functions"
    AddTrailingI32RotlDropToDefinedFunctions =>
      "add-trailing-i32-rotl-drop-to-defined-functions"
    AddLeadingI32RotrDropToDefinedFunctions =>
      "add-leading-i32-rotr-drop-to-defined-functions"
    AddTrailingI32RotrDropToDefinedFunctions =>
      "add-trailing-i32-rotr-drop-to-defined-functions"
    AddLeadingI64RotlDropToDefinedFunctions =>
      "add-leading-i64-rotl-drop-to-defined-functions"
    AddTrailingI64RotlDropToDefinedFunctions =>
      "add-trailing-i64-rotl-drop-to-defined-functions"
    AddLeadingI64RotrDropToDefinedFunctions =>
      "add-leading-i64-rotr-drop-to-defined-functions"
    AddTrailingI64RotrDropToDefinedFunctions =>
      "add-trailing-i64-rotr-drop-to-defined-functions"
    AddLeadingF32AbsDropToDefinedFunctions =>
      "add-leading-f32-abs-drop-to-defined-functions"
    AddTrailingF32AbsDropToDefinedFunctions =>
      "add-trailing-f32-abs-drop-to-defined-functions"
    AddLeadingF64AbsDropToDefinedFunctions =>
      "add-leading-f64-abs-drop-to-defined-functions"
    AddTrailingF64AbsDropToDefinedFunctions =>
      "add-trailing-f64-abs-drop-to-defined-functions"
    AddLeadingF32NegDropToDefinedFunctions =>
      "add-leading-f32-neg-drop-to-defined-functions"
    AddTrailingF32NegDropToDefinedFunctions =>
      "add-trailing-f32-neg-drop-to-defined-functions"
    AddLeadingF64NegDropToDefinedFunctions =>
      "add-leading-f64-neg-drop-to-defined-functions"
    AddTrailingF64NegDropToDefinedFunctions =>
      "add-trailing-f64-neg-drop-to-defined-functions"
    AddLeadingF32SqrtDropToDefinedFunctions =>
      "add-leading-f32-sqrt-drop-to-defined-functions"
    AddTrailingF32SqrtDropToDefinedFunctions =>
      "add-trailing-f32-sqrt-drop-to-defined-functions"
    AddLeadingF64SqrtDropToDefinedFunctions =>
      "add-leading-f64-sqrt-drop-to-defined-functions"
    AddTrailingF64SqrtDropToDefinedFunctions =>
      "add-trailing-f64-sqrt-drop-to-defined-functions"
    AddLeadingF32CeilDropToDefinedFunctions =>
      "add-leading-f32-ceil-drop-to-defined-functions"
    AddTrailingF32CeilDropToDefinedFunctions =>
      "add-trailing-f32-ceil-drop-to-defined-functions"
    AddLeadingF32FloorDropToDefinedFunctions =>
      "add-leading-f32-floor-drop-to-defined-functions"
    AddTrailingF32FloorDropToDefinedFunctions =>
      "add-trailing-f32-floor-drop-to-defined-functions"
    AddLeadingF64CeilDropToDefinedFunctions =>
      "add-leading-f64-ceil-drop-to-defined-functions"
    AddTrailingF64CeilDropToDefinedFunctions =>
      "add-trailing-f64-ceil-drop-to-defined-functions"
    AddLeadingF64FloorDropToDefinedFunctions =>
      "add-leading-f64-floor-drop-to-defined-functions"
    AddTrailingF64FloorDropToDefinedFunctions =>
      "add-trailing-f64-floor-drop-to-defined-functions"
    AddLeadingF32TruncDropToDefinedFunctions =>
      "add-leading-f32-trunc-drop-to-defined-functions"
    AddTrailingF32TruncDropToDefinedFunctions =>
      "add-trailing-f32-trunc-drop-to-defined-functions"
    AddLeadingF32NearestDropToDefinedFunctions =>
      "add-leading-f32-nearest-drop-to-defined-functions"
    AddTrailingF32NearestDropToDefinedFunctions =>
      "add-trailing-f32-nearest-drop-to-defined-functions"
    AddLeadingF64TruncDropToDefinedFunctions =>
      "add-leading-f64-trunc-drop-to-defined-functions"
    AddTrailingF64TruncDropToDefinedFunctions =>
      "add-trailing-f64-trunc-drop-to-defined-functions"
    AddLeadingF64NearestDropToDefinedFunctions =>
      "add-leading-f64-nearest-drop-to-defined-functions"
    AddTrailingF64NearestDropToDefinedFunctions =>
      "add-trailing-f64-nearest-drop-to-defined-functions"
    AddLeadingF32AddDropToDefinedFunctions =>
      "add-leading-f32-add-drop-to-defined-functions"
    AddTrailingF32AddDropToDefinedFunctions =>
      "add-trailing-f32-add-drop-to-defined-functions"
    AddLeadingF32SubDropToDefinedFunctions =>
      "add-leading-f32-sub-drop-to-defined-functions"
    AddTrailingF32SubDropToDefinedFunctions =>
      "add-trailing-f32-sub-drop-to-defined-functions"
    AddLeadingF64AddDropToDefinedFunctions =>
      "add-leading-f64-add-drop-to-defined-functions"
    AddTrailingF64AddDropToDefinedFunctions =>
      "add-trailing-f64-add-drop-to-defined-functions"
    AddLeadingF64SubDropToDefinedFunctions =>
      "add-leading-f64-sub-drop-to-defined-functions"
    AddTrailingF64SubDropToDefinedFunctions =>
      "add-trailing-f64-sub-drop-to-defined-functions"
    AddLeadingF32MulDropToDefinedFunctions =>
      "add-leading-f32-mul-drop-to-defined-functions"
    AddTrailingF32MulDropToDefinedFunctions =>
      "add-trailing-f32-mul-drop-to-defined-functions"
    AddLeadingF32DivDropToDefinedFunctions =>
      "add-leading-f32-div-drop-to-defined-functions"
    AddTrailingF32DivDropToDefinedFunctions =>
      "add-trailing-f32-div-drop-to-defined-functions"
    AddLeadingF64MulDropToDefinedFunctions =>
      "add-leading-f64-mul-drop-to-defined-functions"
    AddTrailingF64MulDropToDefinedFunctions =>
      "add-trailing-f64-mul-drop-to-defined-functions"
    AddLeadingF64DivDropToDefinedFunctions =>
      "add-leading-f64-div-drop-to-defined-functions"
    AddTrailingF64DivDropToDefinedFunctions =>
      "add-trailing-f64-div-drop-to-defined-functions"
    AddLeadingF32MinDropToDefinedFunctions =>
      "add-leading-f32-min-drop-to-defined-functions"
    AddTrailingF32MinDropToDefinedFunctions =>
      "add-trailing-f32-min-drop-to-defined-functions"
    AddLeadingF32MaxDropToDefinedFunctions =>
      "add-leading-f32-max-drop-to-defined-functions"
    AddTrailingF32MaxDropToDefinedFunctions =>
      "add-trailing-f32-max-drop-to-defined-functions"
    AddLeadingF64MinDropToDefinedFunctions =>
      "add-leading-f64-min-drop-to-defined-functions"
    AddTrailingF64MinDropToDefinedFunctions =>
      "add-trailing-f64-min-drop-to-defined-functions"
    AddLeadingF64MaxDropToDefinedFunctions =>
      "add-leading-f64-max-drop-to-defined-functions"
    AddTrailingF64MaxDropToDefinedFunctions =>
      "add-trailing-f64-max-drop-to-defined-functions"
    AddLeadingF32CopysignDropToDefinedFunctions =>
      "add-leading-f32-copysign-drop-to-defined-functions"
    AddTrailingF32CopysignDropToDefinedFunctions =>
      "add-trailing-f32-copysign-drop-to-defined-functions"
    AddLeadingF64CopysignDropToDefinedFunctions =>
      "add-leading-f64-copysign-drop-to-defined-functions"
    AddTrailingF64CopysignDropToDefinedFunctions =>
      "add-trailing-f64-copysign-drop-to-defined-functions"
    AddLeadingF32EqDropToDefinedFunctions =>
      "add-leading-f32-eq-drop-to-defined-functions"
    AddTrailingF32EqDropToDefinedFunctions =>
      "add-trailing-f32-eq-drop-to-defined-functions"
    AddLeadingF32NeDropToDefinedFunctions =>
      "add-leading-f32-ne-drop-to-defined-functions"
    AddTrailingF32NeDropToDefinedFunctions =>
      "add-trailing-f32-ne-drop-to-defined-functions"
    AddLeadingF64EqDropToDefinedFunctions =>
      "add-leading-f64-eq-drop-to-defined-functions"
    AddTrailingF64EqDropToDefinedFunctions =>
      "add-trailing-f64-eq-drop-to-defined-functions"
    AddLeadingF64NeDropToDefinedFunctions =>
      "add-leading-f64-ne-drop-to-defined-functions"
    AddTrailingF64NeDropToDefinedFunctions =>
      "add-trailing-f64-ne-drop-to-defined-functions"
    AddLeadingF32LtDropToDefinedFunctions =>
      "add-leading-f32-lt-drop-to-defined-functions"
    AddTrailingF32LtDropToDefinedFunctions =>
      "add-trailing-f32-lt-drop-to-defined-functions"
    AddLeadingF32GtDropToDefinedFunctions =>
      "add-leading-f32-gt-drop-to-defined-functions"
    AddTrailingF32GtDropToDefinedFunctions =>
      "add-trailing-f32-gt-drop-to-defined-functions"
    AddLeadingF64LtDropToDefinedFunctions =>
      "add-leading-f64-lt-drop-to-defined-functions"
    AddTrailingF64LtDropToDefinedFunctions =>
      "add-trailing-f64-lt-drop-to-defined-functions"
    AddLeadingF64GtDropToDefinedFunctions =>
      "add-leading-f64-gt-drop-to-defined-functions"
    AddTrailingF64GtDropToDefinedFunctions =>
      "add-trailing-f64-gt-drop-to-defined-functions"
    AddLeadingF32LeDropToDefinedFunctions =>
      "add-leading-f32-le-drop-to-defined-functions"
    AddTrailingF32LeDropToDefinedFunctions =>
      "add-trailing-f32-le-drop-to-defined-functions"
    AddLeadingF32GeDropToDefinedFunctions =>
      "add-leading-f32-ge-drop-to-defined-functions"
    AddTrailingF32GeDropToDefinedFunctions =>
      "add-trailing-f32-ge-drop-to-defined-functions"
    AddLeadingF64LeDropToDefinedFunctions =>
      "add-leading-f64-le-drop-to-defined-functions"
    AddTrailingF64LeDropToDefinedFunctions =>
      "add-trailing-f64-le-drop-to-defined-functions"
    AddLeadingF64GeDropToDefinedFunctions =>
      "add-leading-f64-ge-drop-to-defined-functions"
    AddTrailingF64GeDropToDefinedFunctions =>
      "add-trailing-f64-ge-drop-to-defined-functions"
    AddLeadingNopToDefinedFunctions => "add-leading-nop-to-defined-functions"
    AddTrailingNopToDefinedFunctions => "add-trailing-nop-to-defined-functions"
    AddLeadingI32ConstDropToDefinedFunctions =>
      "add-leading-i32-const-drop-to-defined-functions"
    AddTrailingI32ConstDropToDefinedFunctions =>
      "add-trailing-i32-const-drop-to-defined-functions"
    AddTrailingEmptyVoidBlockToDefinedFunctions =>
      "add-trailing-empty-void-block-to-defined-functions"
    AddLeadingEmptyVoidBlockToDefinedFunctions =>
      "add-leading-empty-void-block-to-defined-functions"
    AddLeadingEmptyVoidLoopToDefinedFunctions =>
      "add-leading-empty-void-loop-to-defined-functions"
    SplitMergeLocalDeclarations => "split-merge-local-declarations"
    AddTrailingEmptyVoidLoopToDefinedFunctions =>
      "add-trailing-empty-void-loop-to-defined-functions"
    WrapDefinedFunctionBodiesInIdentityBlock =>
      "wrap-defined-function-bodies-in-identity-block"
    AddExportAliases => "add-export-aliases"
    AddPrefixedExportAliases => "add-prefixed-export-aliases"
    AddSuffixedExportAliases => "add-suffixed-export-aliases"
    ReverseCustomSections => "reverse-custom-sections"
  }
}

///|
pub fn metamorphic_valid_transform_by_id(
  id : String,
) -> Result[MetamorphicValidTransform, String] {
  for transform in metamorphic_valid_transforms() {
    if metamorphic_valid_transform_id(transform) == id {
      return Ok(transform)
    }
  }
  Err("unknown metamorphic transform id: \{id}")
}

///|
pub struct MetamorphicValidTransformResult {
  transform_id : String
  wasm_module : @lib.Module
} derive(Eq, Debug)

///|
pub struct ValidateValidMetamorphicFuzzStats {
  profile : String
  attempts : Int
  generated : Int
  transformed : Int
  validated : Int
  transform_ids : Array[String]
} derive(Eq, Debug)

///|
fn metamorphic_add_non_name_custom_section(mod : @lib.Module) -> @lib.Module {
  let custom_secs = []
  for sec in mod.custom_secs {
    custom_secs.push(sec)
  }
  custom_secs.push(
    @lib.CustomSec::new(
      @lib.Name::from_string(
        "starshine.metamorphic.add-non-name-custom-section",
      ),
      b"semantics-preserving custom payload",
    ),
  )
  mod.with_custom_secs(custom_secs)
}

///|
fn metamorphic_add_leading_non_name_custom_section(
  mod : @lib.Module,
) -> @lib.Module {
  let custom_secs = [
    @lib.CustomSec::new(
      @lib.Name::from_string(
        "starshine.metamorphic.add-leading-non-name-custom-section",
      ),
      b"semantics-preserving leading custom payload",
    ),
  ]
  for sec in mod.custom_secs {
    custom_secs.push(sec)
  }
  mod.with_custom_secs(custom_secs)
}

///|
fn metamorphic_add_custom_section_stress(mod : @lib.Module) -> @lib.Module {
  let custom_secs = []
  for sec in mod.custom_secs {
    custom_secs.push(sec)
  }
  custom_secs.push(
    @lib.CustomSec::new(@lib.Name::from_string("starshine.fuzz.empty"), b""),
  )
  custom_secs.push(
    @lib.CustomSec::new(
      @lib.Name::from_string("starshine.fuzz.bytes"),
      b"\x00\x01\x7f\x80\xffpayload",
    ),
  )
  custom_secs.push(
    @lib.CustomSec::new(
      @lib.Name::from_string("starshine.fuzz.unicode-☄"),
      b"utf8-name custom payload",
    ),
  )
  custom_secs.push(
    @lib.CustomSec::new(
      @lib.Name::from_string("starshine.fuzz.long-payload"),
      b"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
    ),
  )
  mod.with_custom_secs(custom_secs)
}

///|
fn metamorphic_with_name_sec_func_names(
  mod : @lib.Module,
  func_names : @lib.NameMap,
) -> @lib.Module {
  let name_sec = match mod.name_sec {
    Some(existing) =>
      @lib.NameSec::new(
        module_name=existing.module_name,
        func_names=Some(func_names),
        local_names=existing.local_names,
        label_names=existing.label_names,
        type_names=existing.type_names,
        table_names=existing.table_names,
        memory_names=existing.memory_names,
        global_names=existing.global_names,
        elem_names=existing.elem_names,
        data_names=existing.data_names,
        field_names=existing.field_names,
        tag_names=existing.tag_names,
      )
    None => @lib.NameSec::new(func_names=Some(func_names))
  }
  mod.with_name_sec(name_sec)
}

///|
fn metamorphic_with_name_sec_local_names(
  mod : @lib.Module,
  local_names : @lib.IndirectNameMap,
) -> @lib.Module {
  let name_sec = match mod.name_sec {
    Some(existing) =>
      @lib.NameSec::new(
        module_name=existing.module_name,
        func_names=existing.func_names,
        local_names=Some(local_names),
        label_names=existing.label_names,
        type_names=existing.type_names,
        table_names=existing.table_names,
        memory_names=existing.memory_names,
        global_names=existing.global_names,
        elem_names=existing.elem_names,
        data_names=existing.data_names,
        field_names=existing.field_names,
        tag_names=existing.tag_names,
      )
    None => @lib.NameSec::new(local_names=Some(local_names))
  }
  mod.with_name_sec(name_sec)
}

///|
fn metamorphic_with_name_sec_label_names(
  mod : @lib.Module,
  label_names : @lib.IndirectNameMap,
) -> @lib.Module {
  let name_sec = match mod.name_sec {
    Some(existing) =>
      @lib.NameSec::new(
        module_name=existing.module_name,
        func_names=existing.func_names,
        local_names=existing.local_names,
        label_names=Some(label_names),
        type_names=existing.type_names,
        table_names=existing.table_names,
        memory_names=existing.memory_names,
        global_names=existing.global_names,
        elem_names=existing.elem_names,
        data_names=existing.data_names,
        field_names=existing.field_names,
        tag_names=existing.tag_names,
      )
    None => @lib.NameSec::new(label_names=Some(label_names))
  }
  mod.with_name_sec(name_sec)
}

///|
fn metamorphic_with_name_sec_type_names(
  mod : @lib.Module,
  type_names : @lib.NameMap,
) -> @lib.Module {
  let name_sec = match mod.name_sec {
    Some(existing) =>
      @lib.NameSec::new(
        module_name=existing.module_name,
        func_names=existing.func_names,
        local_names=existing.local_names,
        label_names=existing.label_names,
        type_names=Some(type_names),
        table_names=existing.table_names,
        memory_names=existing.memory_names,
        global_names=existing.global_names,
        elem_names=existing.elem_names,
        data_names=existing.data_names,
        field_names=existing.field_names,
        tag_names=existing.tag_names,
      )
    None => @lib.NameSec::new(type_names=Some(type_names))
  }
  mod.with_name_sec(name_sec)
}

///|
fn metamorphic_with_name_sec_global_names(
  mod : @lib.Module,
  global_names : @lib.NameMap,
) -> @lib.Module {
  let name_sec = match mod.name_sec {
    Some(existing) =>
      @lib.NameSec::new(
        module_name=existing.module_name,
        func_names=existing.func_names,
        local_names=existing.local_names,
        label_names=existing.label_names,
        type_names=existing.type_names,
        table_names=existing.table_names,
        memory_names=existing.memory_names,
        global_names=Some(global_names),
        elem_names=existing.elem_names,
        data_names=existing.data_names,
        field_names=existing.field_names,
        tag_names=existing.tag_names,
      )
    None => @lib.NameSec::new(global_names=Some(global_names))
  }
  mod.with_name_sec(name_sec)
}

///|
fn metamorphic_with_name_sec_table_names(
  mod : @lib.Module,
  table_names : @lib.NameMap,
) -> @lib.Module {
  let name_sec = match mod.name_sec {
    Some(existing) =>
      @lib.NameSec::new(
        module_name=existing.module_name,
        func_names=existing.func_names,
        local_names=existing.local_names,
        label_names=existing.label_names,
        type_names=existing.type_names,
        table_names=Some(table_names),
        memory_names=existing.memory_names,
        global_names=existing.global_names,
        elem_names=existing.elem_names,
        data_names=existing.data_names,
        field_names=existing.field_names,
        tag_names=existing.tag_names,
      )
    None => @lib.NameSec::new(table_names=Some(table_names))
  }
  mod.with_name_sec(name_sec)
}

///|
fn metamorphic_with_name_sec_memory_names(
  mod : @lib.Module,
  memory_names : @lib.NameMap,
) -> @lib.Module {
  let name_sec = match mod.name_sec {
    Some(existing) =>
      @lib.NameSec::new(
        module_name=existing.module_name,
        func_names=existing.func_names,
        local_names=existing.local_names,
        label_names=existing.label_names,
        type_names=existing.type_names,
        table_names=existing.table_names,
        memory_names=Some(memory_names),
        global_names=existing.global_names,
        elem_names=existing.elem_names,
        data_names=existing.data_names,
        field_names=existing.field_names,
        tag_names=existing.tag_names,
      )
    None => @lib.NameSec::new(memory_names=Some(memory_names))
  }
  mod.with_name_sec(name_sec)
}

///|
fn metamorphic_with_name_sec_data_names(
  mod : @lib.Module,
  data_names : @lib.NameMap,
) -> @lib.Module {
  let name_sec = match mod.name_sec {
    Some(existing) =>
      @lib.NameSec::new(
        module_name=existing.module_name,
        func_names=existing.func_names,
        local_names=existing.local_names,
        label_names=existing.label_names,
        type_names=existing.type_names,
        table_names=existing.table_names,
        memory_names=existing.memory_names,
        global_names=existing.global_names,
        elem_names=existing.elem_names,
        data_names=Some(data_names),
        field_names=existing.field_names,
        tag_names=existing.tag_names,
      )
    None => @lib.NameSec::new(data_names=Some(data_names))
  }
  mod.with_name_sec(name_sec)
}

///|
fn metamorphic_with_name_sec_elem_names(
  mod : @lib.Module,
  elem_names : @lib.NameMap,
) -> @lib.Module {
  let name_sec = match mod.name_sec {
    Some(existing) =>
      @lib.NameSec::new(
        module_name=existing.module_name,
        func_names=existing.func_names,
        local_names=existing.local_names,
        label_names=existing.label_names,
        type_names=existing.type_names,
        table_names=existing.table_names,
        memory_names=existing.memory_names,
        global_names=existing.global_names,
        elem_names=Some(elem_names),
        data_names=existing.data_names,
        field_names=existing.field_names,
        tag_names=existing.tag_names,
      )
    None => @lib.NameSec::new(elem_names=Some(elem_names))
  }
  mod.with_name_sec(name_sec)
}

///|
fn metamorphic_with_name_sec_tag_names(
  mod : @lib.Module,
  tag_names : @lib.NameMap,
) -> @lib.Module {
  let name_sec = match mod.name_sec {
    Some(existing) =>
      @lib.NameSec::new(
        module_name=existing.module_name,
        func_names=existing.func_names,
        local_names=existing.local_names,
        label_names=existing.label_names,
        type_names=existing.type_names,
        table_names=existing.table_names,
        memory_names=existing.memory_names,
        global_names=existing.global_names,
        elem_names=existing.elem_names,
        data_names=existing.data_names,
        field_names=existing.field_names,
        tag_names=Some(tag_names),
      )
    None => @lib.NameSec::new(tag_names=Some(tag_names))
  }
  mod.with_name_sec(name_sec)
}

///|
fn metamorphic_with_name_sec_field_names(
  mod : @lib.Module,
  field_names : @lib.IndirectNameMap,
) -> @lib.Module {
  let name_sec = match mod.name_sec {
    Some(existing) =>
      @lib.NameSec::new(
        module_name=existing.module_name,
        func_names=existing.func_names,
        local_names=existing.local_names,
        label_names=existing.label_names,
        type_names=existing.type_names,
        table_names=existing.table_names,
        memory_names=existing.memory_names,
        global_names=existing.global_names,
        elem_names=existing.elem_names,
        data_names=existing.data_names,
        field_names=Some(field_names),
        tag_names=existing.tag_names,
      )
    None => @lib.NameSec::new(field_names=Some(field_names))
  }
  mod.with_name_sec(name_sec)
}

///|
fn metamorphic_add_module_name_section(mod : @lib.Module) -> @lib.Module {
  mod.with_name_sec(
    @lib.NameSec::new(
      module_name=Some(@lib.Name::from_string("starshine.metamorphic.module")),
    ),
  )
}

///|
fn metamorphic_total_func_count(mod : @lib.Module) -> Int {
  let mut count = 0
  match mod.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.FuncExternType(_)) => count += 1
          _ => ()
        }
      }
    None => ()
  }
  match mod.func_sec {
    Some(@lib.FuncSec(type_idxs)) => count += type_idxs.length()
    None => ()
  }
  count
}

///|
fn metamorphic_add_function_names_section(mod : @lib.Module) -> @lib.Module {
  let names = []
  let count = metamorphic_total_func_count(mod)
  for i = 0; i < count; i = i + 1 {
    names.push(
      @lib.NameAssoc::new(
        i.reinterpret_as_uint(),
        @lib.Name::from_string("metamorphic_func_\{i}"),
      ),
    )
  }
  metamorphic_with_name_sec_func_names(mod, @lib.NameMap::new(names))
}

///|
fn metamorphic_flatten_types(mod : @lib.Module) -> Array[@lib.SubType] {
  let subtypes : Array[@lib.SubType] = []
  match mod.type_sec {
    Some(@lib.TypeSec(rec_types)) =>
      for rec_type in rec_types {
        match rec_type {
          @lib.SingleRecType(sub_type) => subtypes.push(sub_type)
          @lib.GroupRecType(group) =>
            for sub_type in group {
              subtypes.push(sub_type)
            }
        }
      }
    None => ()
  }
  subtypes
}

///|
fn metamorphic_func_param_count(
  subtypes : Array[@lib.SubType],
  type_idx : @lib.TypeIdx,
) -> Int {
  match type_idx {
    @lib.TypeIdx(i) =>
      match subtypes.get(i.reinterpret_as_int()) {
        Some(sub_type) =>
          match sub_type.get_comptype() {
            @lib.FuncCompType(params, _) => params.length()
            _ => 0
          }
        None => 0
      }
    @lib.RecIdx(_) => 0
  }
}

///|
fn metamorphic_add_type_names_section(mod : @lib.Module) -> @lib.Module {
  let names = []
  let subtypes = metamorphic_flatten_types(mod)
  for i = 0; i < subtypes.length(); i = i + 1 {
    names.push(
      @lib.NameAssoc::new(
        i.reinterpret_as_uint(),
        @lib.Name::from_string("metamorphic_type_\{i}"),
      ),
    )
  }
  metamorphic_with_name_sec_type_names(mod, @lib.NameMap::new(names))
}

///|
fn metamorphic_add_global_names_section(mod : @lib.Module) -> @lib.Module {
  let names = []
  let mut count = 0
  match mod.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.GlobalExternType(_)) => count += 1
          _ => ()
        }
      }
    None => ()
  }
  match mod.global_sec {
    Some(@lib.GlobalSec(globals)) => count += globals.length()
    None => ()
  }
  for i = 0; i < count; i = i + 1 {
    names.push(
      @lib.NameAssoc::new(
        i.reinterpret_as_uint(),
        @lib.Name::from_string("metamorphic_global_\{i}"),
      ),
    )
  }
  metamorphic_with_name_sec_global_names(mod, @lib.NameMap::new(names))
}

///|
fn metamorphic_add_table_names_section(mod : @lib.Module) -> @lib.Module {
  let names = []
  let mut count = 0
  match mod.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.TableExternType(_)) => count += 1
          _ => ()
        }
      }
    None => ()
  }
  match mod.table_sec {
    Some(@lib.TableSec(tables)) => count += tables.length()
    None => ()
  }
  for i = 0; i < count; i = i + 1 {
    names.push(
      @lib.NameAssoc::new(
        i.reinterpret_as_uint(),
        @lib.Name::from_string("metamorphic_table_\{i}"),
      ),
    )
  }
  metamorphic_with_name_sec_table_names(mod, @lib.NameMap::new(names))
}

///|
fn metamorphic_add_memory_names_section(mod : @lib.Module) -> @lib.Module {
  let names = []
  let mut count = 0
  match mod.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.MemExternType(_)) => count += 1
          _ => ()
        }
      }
    None => ()
  }
  match mod.mem_sec {
    Some(@lib.MemSec(mems)) => count += mems.length()
    None => ()
  }
  for i = 0; i < count; i = i + 1 {
    names.push(
      @lib.NameAssoc::new(
        i.reinterpret_as_uint(),
        @lib.Name::from_string("metamorphic_memory_\{i}"),
      ),
    )
  }
  metamorphic_with_name_sec_memory_names(mod, @lib.NameMap::new(names))
}

///|
fn metamorphic_add_data_names_section(mod : @lib.Module) -> @lib.Module {
  let names = []
  let count = match mod.data_sec {
    Some(@lib.DataSec(datas)) => datas.length()
    None => 0
  }
  for i = 0; i < count; i = i + 1 {
    names.push(
      @lib.NameAssoc::new(
        i.reinterpret_as_uint(),
        @lib.Name::from_string("metamorphic_data_\{i}"),
      ),
    )
  }
  metamorphic_with_name_sec_data_names(mod, @lib.NameMap::new(names))
}

///|
fn metamorphic_add_elem_names_section(mod : @lib.Module) -> @lib.Module {
  let names = []
  let count = match mod.elem_sec {
    Some(@lib.ElemSec(elems)) => elems.length()
    None => 0
  }
  for i = 0; i < count; i = i + 1 {
    names.push(
      @lib.NameAssoc::new(
        i.reinterpret_as_uint(),
        @lib.Name::from_string("metamorphic_elem_\{i}"),
      ),
    )
  }
  metamorphic_with_name_sec_elem_names(mod, @lib.NameMap::new(names))
}

///|
fn metamorphic_add_tag_names_section(mod : @lib.Module) -> @lib.Module {
  let names = []
  let mut count = 0
  match mod.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.TagExternType(_)) => count += 1
          _ => ()
        }
      }
    None => ()
  }
  match mod.tag_sec {
    Some(@lib.TagSec(tags)) => count += tags.length()
    None => ()
  }
  for i = 0; i < count; i = i + 1 {
    names.push(
      @lib.NameAssoc::new(
        i.reinterpret_as_uint(),
        @lib.Name::from_string("metamorphic_tag_\{i}"),
      ),
    )
  }
  metamorphic_with_name_sec_tag_names(mod, @lib.NameMap::new(names))
}

///|
fn metamorphic_add_field_names_section(mod : @lib.Module) -> @lib.Module {
  let entries : Array[@lib.IndirectNameAssoc] = []
  let subtypes = metamorphic_flatten_types(mod)
  for type_idx = 0; type_idx < subtypes.length(); type_idx = type_idx + 1 {
    match subtypes[type_idx].get_comptype() {
      @lib.StructCompType(fields) => {
        let field_entries : Array[@lib.NameAssoc] = []
        for field_idx = 0
            field_idx < fields.length()
            field_idx = field_idx + 1 {
          field_entries.push(
            @lib.NameAssoc::new(
              field_idx.reinterpret_as_uint(),
              @lib.Name::from_string(
                "metamorphic_field_\{type_idx}_\{field_idx}",
              ),
            ),
          )
        }
        entries.push(
          @lib.IndirectNameAssoc::new(
            type_idx.reinterpret_as_uint(),
            @lib.NameMap::new(field_entries),
          ),
        )
      }
      _ => ()
    }
  }
  metamorphic_with_name_sec_field_names(mod, @lib.IndirectNameMap::new(entries))
}

///|
fn metamorphic_instr_label_count(instr : @lib.Instruction) -> Int {
  match instr {
    @lib.Block(_, body) | @lib.Loop(_, body) | @lib.TryTable(_, _, body) =>
      1 + metamorphic_expr_label_count(body)
    @lib.If(_, then_instrs, else_instrs) => {
      let else_count = match else_instrs {
        Some(instrs) => metamorphic_instrs_label_count(instrs)
        None => 0
      }
      1 + metamorphic_instrs_label_count(then_instrs) + else_count
    }
    _ => 0
  }
}

///|
fn metamorphic_instrs_label_count(instrs : Array[@lib.Instruction]) -> Int {
  let mut total = 0
  for instr in instrs {
    total += metamorphic_instr_label_count(instr)
  }
  total
}

///|
fn metamorphic_expr_label_count(expr : @lib.Expr) -> Int {
  let @lib.Expr(instrs) = expr
  metamorphic_instrs_label_count(instrs)
}

///|
fn metamorphic_add_label_names_section(mod : @lib.Module) -> @lib.Module {
  let entries : Array[@lib.IndirectNameAssoc] = []
  let mut abs_func_idx = 0
  match mod.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.FuncExternType(_)) => abs_func_idx += 1
          _ => ()
        }
      }
    None => ()
  }
  match mod.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func in funcs {
        let label_entries : Array[@lib.NameAssoc] = []
        let label_count = match func {
          @lib.Func(_, expr) => metamorphic_expr_label_count(expr)
        }
        for label_idx = 0; label_idx < label_count; label_idx = label_idx + 1 {
          label_entries.push(
            @lib.NameAssoc::new(
              label_idx.reinterpret_as_uint(),
              @lib.Name::from_string(
                "metamorphic_label_\{abs_func_idx}_\{label_idx}",
              ),
            ),
          )
        }
        if label_entries.length() > 0 {
          entries.push(
            @lib.IndirectNameAssoc::new(
              abs_func_idx.reinterpret_as_uint(),
              @lib.NameMap::new(label_entries),
            ),
          )
        }
        abs_func_idx += 1
      }
    None => ()
  }
  metamorphic_with_name_sec_label_names(mod, @lib.IndirectNameMap::new(entries))
}

///|
fn metamorphic_add_local_names_section(mod : @lib.Module) -> @lib.Module {
  let subtypes = metamorphic_flatten_types(mod)
  let entries : Array[@lib.IndirectNameAssoc] = []
  let mut abs_func_idx = 0
  match mod.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.FuncExternType(type_idx)) => {
            let local_entries : Array[@lib.NameAssoc] = []
            let count = metamorphic_func_param_count(subtypes, type_idx)
            for local_idx = 0; local_idx < count; local_idx = local_idx + 1 {
              local_entries.push(
                @lib.NameAssoc::new(
                  local_idx.reinterpret_as_uint(),
                  @lib.Name::from_string(
                    "metamorphic_local_\{abs_func_idx}_\{local_idx}",
                  ),
                ),
              )
            }
            entries.push(
              @lib.IndirectNameAssoc::new(
                abs_func_idx.reinterpret_as_uint(),
                @lib.NameMap::new(local_entries),
              ),
            )
            abs_func_idx += 1
          }
          _ => ()
        }
      }
    None => ()
  }
  match (mod.func_sec, mod.code_sec) {
    (Some(@lib.FuncSec(type_idxs)), Some(@lib.CodeSec(funcs))) => {
      let count = if type_idxs.length() < funcs.length() {
        type_idxs.length()
      } else {
        funcs.length()
      }
      for def_idx = 0; def_idx < count; def_idx = def_idx + 1 {
        let param_count = metamorphic_func_param_count(
          subtypes,
          type_idxs[def_idx],
        )
        let local_count = match funcs[def_idx] {
          @lib.Func(locals, _) => param_count + locals.length()
        }
        let local_entries : Array[@lib.NameAssoc] = []
        for local_idx = 0; local_idx < local_count; local_idx = local_idx + 1 {
          local_entries.push(
            @lib.NameAssoc::new(
              local_idx.reinterpret_as_uint(),
              @lib.Name::from_string(
                "metamorphic_local_\{abs_func_idx}_\{local_idx}",
              ),
            ),
          )
        }
        entries.push(
          @lib.IndirectNameAssoc::new(
            abs_func_idx.reinterpret_as_uint(),
            @lib.NameMap::new(local_entries),
          ),
        )
        abs_func_idx += 1
      }
    }
    _ => ()
  }
  metamorphic_with_name_sec_local_names(mod, @lib.IndirectNameMap::new(entries))
}

///|
fn metamorphic_add_unused_passive_data_segment(
  mod : @lib.Module,
) -> @lib.Module {
  let datas = []
  match mod.data_sec {
    Some(@lib.DataSec(existing)) =>
      for data in existing {
        datas.push(data)
      }
    None => ()
  }
  datas.push(
    @lib.Data::new(
      @lib.DataMode::passive(),
      b"starshine metamorphic passive data",
    ),
  )
  mod
  .with_data_cnt_sec(
    @lib.DataCntSec::new(@lib.U32(datas.length().reinterpret_as_uint())),
  )
  .with_data_sec(@lib.DataSec::new(datas))
}

///|
fn metamorphic_add_unused_immutable_i32_global(
  mod : @lib.Module,
) -> @lib.Module {
  let globals = []
  match mod.global_sec {
    Some(@lib.GlobalSec(existing)) =>
      for global in existing {
        globals.push(global)
      }
    None => ()
  }
  globals.push(
    @lib.Global::new(
      @lib.GlobalType::new(@lib.ValType::i32(), false),
      @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
    ),
  )
  mod.with_global_sec(@lib.GlobalSec::new(globals))
}

///|
fn metamorphic_count_flat_types(rec_types : Array[@lib.RecType]) -> Int {
  let mut count = 0
  for rec_type in rec_types {
    match rec_type {
      @lib.SingleRecType(_) => count += 1
      @lib.GroupRecType(group) => count += group.length()
    }
  }
  count
}

///|
fn metamorphic_add_unused_funcref_table(mod : @lib.Module) -> @lib.Module {
  let tables = []
  match mod.table_sec {
    Some(@lib.TableSec(existing)) =>
      for table in existing {
        tables.push(table)
      }
    None => ()
  }
  tables.push(
    @lib.Table::new(
      @lib.TableType::new(
        @lib.RefType::abs(@lib.AbsHeapType::func()),
        @lib.Limits::i32(0U, Some(0U)),
      ),
      None,
    ),
  )
  mod.with_table_sec(@lib.TableSec::new(tables))
}

///|
fn metamorphic_add_unused_passive_funcref_element_segment(
  mod : @lib.Module,
) -> @lib.Module {
  let elems = []
  match mod.elem_sec {
    Some(@lib.ElemSec(existing)) =>
      for elem in existing {
        elems.push(elem)
      }
    None => ()
  }
  elems.push(@lib.Elem::new(@lib.ElemMode::passive(), @lib.ElemKind::funcs([])))
  mod.with_elem_sec(@lib.ElemSec::new(elems))
}

///|
fn metamorphic_add_unused_empty_function_type(mod : @lib.Module) -> @lib.Module {
  let types = []
  match mod.type_sec {
    Some(@lib.TypeSec(existing)) =>
      for rec_type in existing {
        types.push(rec_type)
      }
    None => ()
  }
  types.push(
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
  )
  mod.with_type_sec(@lib.TypeSec::new(types))
}

///|
fn metamorphic_add_duplicate_equivalent_function_type(
  mod : @lib.Module,
) -> @lib.Module {
  let types = []
  let mut duplicate : @lib.RecType? = None
  match mod.type_sec {
    Some(@lib.TypeSec(existing)) =>
      for rec_type in existing {
        types.push(rec_type)
        if duplicate is None {
          match rec_type {
            @lib.SingleRecType(@lib.CompTypeSubType(_, @lib.FuncCompType(_, _))) =>
              duplicate = Some(rec_type)
            _ => ()
          }
        }
      }
    None => ()
  }
  match duplicate {
    Some(rec_type) => types.push(rec_type)
    None =>
      types.push(
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      )
  }
  mod.with_type_sec(@lib.TypeSec::new(types))
}

///|
fn metamorphic_add_unused_i32_local_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  let funcs = []
  match mod.code_sec {
    Some(@lib.CodeSec(existing)) =>
      for func in existing {
        match func {
          @lib.Func(locals, expr) => {
            let next_locals = locals.copy()
            next_locals.push(@lib.ValType::i32())
            funcs.push(@lib.Func::new(next_locals, expr))
          }
        }
      }
    None => return mod
  }
  mod.with_code_sec(@lib.CodeSec::new(funcs))
}

///|
fn metamorphic_add_unused_numeric_locals_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  let funcs = []
  match mod.code_sec {
    Some(@lib.CodeSec(existing)) =>
      for func in existing {
        match func {
          @lib.Func(locals, expr) => {
            let next_locals = locals.copy()
            next_locals.push(@lib.ValType::i64())
            next_locals.push(@lib.ValType::f32())
            next_locals.push(@lib.ValType::f64())
            funcs.push(@lib.Func::new(next_locals, expr))
          }
        }
      }
    None => return mod
  }
  mod.with_code_sec(@lib.CodeSec::new(funcs))
}

///|
fn metamorphic_add_unused_reference_locals_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  let funcs = []
  match mod.code_sec {
    Some(@lib.CodeSec(existing)) =>
      for func in existing {
        match func {
          @lib.Func(locals, expr) => {
            let next_locals = locals.copy()
            next_locals.push(@lib.ValType::funcref())
            next_locals.push(@lib.ValType::externref())
            funcs.push(@lib.Func::new(next_locals, expr))
          }
        }
      }
    None => return mod
  }
  mod.with_code_sec(@lib.CodeSec::new(funcs))
}

///|
fn metamorphic_add_unused_v128_local_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  let funcs = []
  match mod.code_sec {
    Some(@lib.CodeSec(existing)) =>
      for func in existing {
        match func {
          @lib.Func(locals, expr) => {
            let next_locals = locals.copy()
            next_locals.push(@lib.ValType::v128())
            funcs.push(@lib.Func::new(next_locals, expr))
          }
        }
      }
    None => return mod
  }
  mod.with_code_sec(@lib.CodeSec::new(funcs))
}

///|
fn metamorphic_add_unused_gc_reference_locals_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  let funcs = []
  match mod.code_sec {
    Some(@lib.CodeSec(existing)) =>
      for func in existing {
        match func {
          @lib.Func(locals, expr) => {
            let next_locals = locals.copy()
            next_locals.push(@lib.ValType::anyref())
            next_locals.push(@lib.ValType::i31ref_nullable())
            next_locals.push(@lib.ValType::stringref())
            funcs.push(@lib.Func::new(next_locals, expr))
          }
        }
      }
    None => return mod
  }
  mod.with_code_sec(@lib.CodeSec::new(funcs))
}

///|
fn metamorphic_add_leading_ref_null_drop_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  let funcs = []
  match mod.code_sec {
    Some(@lib.CodeSec(existing)) =>
      for func in existing {
        match func {
          @lib.Func(locals, @lib.Expr(instrs)) => {
            let next_instrs = [
              @lib.Instruction::ref_null(
                @lib.HeapType::abs(@lib.AbsHeapType::extern_()),
              ),
              @lib.Instruction::drop(),
            ]
            for instr in instrs {
              next_instrs.push(instr)
            }
            funcs.push(@lib.Func::new(locals, @lib.Expr::new(next_instrs)))
          }
        }
      }
    None => return mod
  }
  mod.with_code_sec(@lib.CodeSec::new(funcs))
}

///|
fn metamorphic_add_trailing_ref_null_drop_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  let funcs = []
  match mod.code_sec {
    Some(@lib.CodeSec(existing)) =>
      for func in existing {
        match func {
          @lib.Func(locals, @lib.Expr(instrs)) => {
            let next_instrs = []
            for instr in instrs {
              next_instrs.push(instr)
            }
            next_instrs.push(
              @lib.Instruction::ref_null(
                @lib.HeapType::abs(@lib.AbsHeapType::extern_()),
              ),
            )
            next_instrs.push(@lib.Instruction::drop())
            funcs.push(@lib.Func::new(locals, @lib.Expr::new(next_instrs)))
          }
        }
      }
    None => return mod
  }
  mod.with_code_sec(@lib.CodeSec::new(funcs))
}

///|
fn metamorphic_add_leading_i64_const_drop_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  let funcs = []
  match mod.code_sec {
    Some(@lib.CodeSec(existing)) =>
      for func in existing {
        match func {
          @lib.Func(locals, @lib.Expr(instrs)) => {
            let next_instrs = [
              @lib.Instruction::i64_const(@lib.I64(0L)),
              @lib.Instruction::drop(),
            ]
            for instr in instrs {
              next_instrs.push(instr)
            }
            funcs.push(@lib.Func::new(locals, @lib.Expr::new(next_instrs)))
          }
        }
      }
    None => return mod
  }
  mod.with_code_sec(@lib.CodeSec::new(funcs))
}

///|
fn metamorphic_add_trailing_i64_const_drop_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  let funcs = []
  match mod.code_sec {
    Some(@lib.CodeSec(existing)) =>
      for func in existing {
        match func {
          @lib.Func(locals, @lib.Expr(instrs)) => {
            let next_instrs = []
            for instr in instrs {
              next_instrs.push(instr)
            }
            next_instrs.push(@lib.Instruction::i64_const(@lib.I64(0L)))
            next_instrs.push(@lib.Instruction::drop())
            funcs.push(@lib.Func::new(locals, @lib.Expr::new(next_instrs)))
          }
        }
      }
    None => return mod
  }
  mod.with_code_sec(@lib.CodeSec::new(funcs))
}

///|
fn metamorphic_add_leading_f32_const_drop_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  let funcs = []
  match mod.code_sec {
    Some(@lib.CodeSec(existing)) =>
      for func in existing {
        match func {
          @lib.Func(locals, @lib.Expr(instrs)) => {
            let next_instrs = [
              @lib.Instruction::f32_const(@lib.F32(0.0)),
              @lib.Instruction::drop(),
            ]
            for instr in instrs {
              next_instrs.push(instr)
            }
            funcs.push(@lib.Func::new(locals, @lib.Expr::new(next_instrs)))
          }
        }
      }
    None => return mod
  }
  mod.with_code_sec(@lib.CodeSec::new(funcs))
}

///|
fn metamorphic_add_trailing_f32_const_drop_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  let funcs = []
  match mod.code_sec {
    Some(@lib.CodeSec(existing)) =>
      for func in existing {
        match func {
          @lib.Func(locals, @lib.Expr(instrs)) => {
            let next_instrs = []
            for instr in instrs {
              next_instrs.push(instr)
            }
            next_instrs.push(@lib.Instruction::f32_const(@lib.F32(0.0)))
            next_instrs.push(@lib.Instruction::drop())
            funcs.push(@lib.Func::new(locals, @lib.Expr::new(next_instrs)))
          }
        }
      }
    None => return mod
  }
  mod.with_code_sec(@lib.CodeSec::new(funcs))
}

///|
fn metamorphic_add_leading_f64_const_drop_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  let funcs = []
  match mod.code_sec {
    Some(@lib.CodeSec(existing)) =>
      for func in existing {
        match func {
          @lib.Func(locals, @lib.Expr(instrs)) => {
            let next_instrs = [
              @lib.Instruction::f64_const(@lib.F64(0.0)),
              @lib.Instruction::drop(),
            ]
            for instr in instrs {
              next_instrs.push(instr)
            }
            funcs.push(@lib.Func::new(locals, @lib.Expr::new(next_instrs)))
          }
        }
      }
    None => return mod
  }
  mod.with_code_sec(@lib.CodeSec::new(funcs))
}

///|
fn metamorphic_add_trailing_f64_const_drop_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  let funcs = []
  match mod.code_sec {
    Some(@lib.CodeSec(existing)) =>
      for func in existing {
        match func {
          @lib.Func(locals, @lib.Expr(instrs)) => {
            let next_instrs = []
            for instr in instrs {
              next_instrs.push(instr)
            }
            next_instrs.push(@lib.Instruction::f64_const(@lib.F64(0.0)))
            next_instrs.push(@lib.Instruction::drop())
            funcs.push(@lib.Func::new(locals, @lib.Expr::new(next_instrs)))
          }
        }
      }
    None => return mod
  }
  mod.with_code_sec(@lib.CodeSec::new(funcs))
}

///|
fn metamorphic_add_leading_false_if_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  let funcs = []
  match mod.code_sec {
    Some(@lib.CodeSec(existing)) =>
      for func in existing {
        match func {
          @lib.Func(locals, @lib.Expr(instrs)) => {
            let next_instrs = [
              @lib.Instruction::i32_const(0),
              @lib.Instruction::if_(@lib.BlockType::void_(), [], None),
            ]
            for instr in instrs {
              next_instrs.push(instr)
            }
            funcs.push(@lib.Func::new(locals, @lib.Expr::new(next_instrs)))
          }
        }
      }
    None => return mod
  }
  mod.with_code_sec(@lib.CodeSec::new(funcs))
}

///|
fn metamorphic_add_trailing_false_if_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  metamorphic_add_if_to_defined_functions(mod, 0, false)
}

///|
fn metamorphic_add_leading_true_if_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  metamorphic_add_if_to_defined_functions(mod, 1, true)
}

///|
fn metamorphic_add_trailing_true_if_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  metamorphic_add_if_to_defined_functions(mod, 1, false)
}

///|
fn metamorphic_add_leading_i32_eqz_drop_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  metamorphic_add_i32_eqz_drop_to_defined_functions(mod, true)
}

///|
fn metamorphic_add_trailing_i32_eqz_drop_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  metamorphic_add_i32_eqz_drop_to_defined_functions(mod, false)
}

///|
fn metamorphic_add_leading_i64_eqz_drop_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  metamorphic_add_i64_eqz_drop_to_defined_functions(mod, true)
}

///|
fn metamorphic_add_trailing_i64_eqz_drop_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  metamorphic_add_i64_eqz_drop_to_defined_functions(mod, false)
}

///|
fn metamorphic_add_leading_f32_abs_drop_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  metamorphic_add_f32_abs_drop_to_defined_functions(mod, true)
}

///|
fn metamorphic_add_trailing_f32_abs_drop_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  metamorphic_add_f32_abs_drop_to_defined_functions(mod, false)
}

///|
fn metamorphic_add_leading_f64_abs_drop_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  metamorphic_add_f64_abs_drop_to_defined_functions(mod, true)
}

///|
fn metamorphic_add_trailing_f64_abs_drop_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  metamorphic_add_f64_abs_drop_to_defined_functions(mod, false)
}

///|
fn metamorphic_add_leading_f32_neg_drop_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  metamorphic_add_f32_neg_drop_to_defined_functions(mod, true)
}

///|
fn metamorphic_add_trailing_f32_neg_drop_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  metamorphic_add_f32_neg_drop_to_defined_functions(mod, false)
}

///|
fn metamorphic_add_leading_f64_neg_drop_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  metamorphic_add_f64_neg_drop_to_defined_functions(mod, true)
}

///|
fn metamorphic_add_trailing_f64_neg_drop_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  metamorphic_add_f64_neg_drop_to_defined_functions(mod, false)
}

///|
fn metamorphic_add_leading_f32_sqrt_drop_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  metamorphic_add_f32_sqrt_drop_to_defined_functions(mod, true)
}

///|
fn metamorphic_add_trailing_f32_sqrt_drop_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  metamorphic_add_f32_sqrt_drop_to_defined_functions(mod, false)
}

///|
fn metamorphic_add_leading_f64_sqrt_drop_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  metamorphic_add_f64_sqrt_drop_to_defined_functions(mod, true)
}

///|
fn metamorphic_add_trailing_f64_sqrt_drop_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  metamorphic_add_f64_sqrt_drop_to_defined_functions(mod, false)
}

///|
fn metamorphic_add_leading_f32_ceil_drop_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  metamorphic_add_f32_ceil_drop_to_defined_functions(mod, true)
}

///|
fn metamorphic_add_trailing_f32_ceil_drop_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  metamorphic_add_f32_ceil_drop_to_defined_functions(mod, false)
}

///|
fn metamorphic_add_leading_f32_floor_drop_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  metamorphic_add_f32_floor_drop_to_defined_functions(mod, true)
}

///|
fn metamorphic_add_trailing_f32_floor_drop_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  metamorphic_add_f32_floor_drop_to_defined_functions(mod, false)
}

///|
fn metamorphic_add_leading_f64_ceil_drop_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  metamorphic_add_f64_ceil_drop_to_defined_functions(mod, true)
}

///|
fn metamorphic_add_trailing_f64_ceil_drop_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  metamorphic_add_f64_ceil_drop_to_defined_functions(mod, false)
}

///|
fn metamorphic_add_leading_f64_floor_drop_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  metamorphic_add_f64_floor_drop_to_defined_functions(mod, true)
}

///|
fn metamorphic_add_trailing_f64_floor_drop_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  metamorphic_add_f64_floor_drop_to_defined_functions(mod, false)
}

///|
fn metamorphic_add_leading_f32_trunc_drop_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  metamorphic_add_f32_trunc_drop_to_defined_functions(mod, true)
}

///|
fn metamorphic_add_trailing_f32_trunc_drop_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  metamorphic_add_f32_trunc_drop_to_defined_functions(mod, false)
}

///|
fn metamorphic_add_leading_f32_nearest_drop_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  metamorphic_add_f32_nearest_drop_to_defined_functions(mod, true)
}

///|
fn metamorphic_add_trailing_f32_nearest_drop_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  metamorphic_add_f32_nearest_drop_to_defined_functions(mod, false)
}

///|
fn metamorphic_add_leading_f64_trunc_drop_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  metamorphic_add_f64_trunc_drop_to_defined_functions(mod, true)
}

///|
fn metamorphic_add_trailing_f64_trunc_drop_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  metamorphic_add_f64_trunc_drop_to_defined_functions(mod, false)
}

///|
fn metamorphic_add_leading_f64_nearest_drop_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  metamorphic_add_f64_nearest_drop_to_defined_functions(mod, true)
}

///|
fn metamorphic_add_trailing_f64_nearest_drop_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  metamorphic_add_f64_nearest_drop_to_defined_functions(mod, false)
}

///|
fn metamorphic_add_i32_eqz_drop_to_defined_functions(
  mod : @lib.Module,
  leading : Bool,
) -> @lib.Module {
  metamorphic_add_unary_drop_to_defined_functions(mod, leading, [
    @lib.Instruction::i32_const(0),
    @lib.Instruction::i32_eqz(),
    @lib.Instruction::drop(),
  ])
}

///|
fn metamorphic_add_i64_eqz_drop_to_defined_functions(
  mod : @lib.Module,
  leading : Bool,
) -> @lib.Module {
  metamorphic_add_unary_drop_to_defined_functions(mod, leading, [
    @lib.Instruction::i64_const(0L),
    @lib.Instruction::i64_eqz(),
    @lib.Instruction::drop(),
  ])
}

///|
fn metamorphic_add_f32_abs_drop_to_defined_functions(
  mod : @lib.Module,
  leading : Bool,
) -> @lib.Module {
  metamorphic_add_unary_drop_to_defined_functions(mod, leading, [
    @lib.Instruction::f32_const(0.0),
    @lib.Instruction::f32_abs(),
    @lib.Instruction::drop(),
  ])
}

///|
fn metamorphic_add_f64_abs_drop_to_defined_functions(
  mod : @lib.Module,
  leading : Bool,
) -> @lib.Module {
  metamorphic_add_unary_drop_to_defined_functions(mod, leading, [
    @lib.Instruction::f64_const(0.0),
    @lib.Instruction::f64_abs(),
    @lib.Instruction::drop(),
  ])
}

///|
fn metamorphic_add_f32_neg_drop_to_defined_functions(
  mod : @lib.Module,
  leading : Bool,
) -> @lib.Module {
  metamorphic_add_unary_drop_to_defined_functions(mod, leading, [
    @lib.Instruction::f32_const(0.0),
    @lib.Instruction::f32_neg(),
    @lib.Instruction::drop(),
  ])
}

///|
fn metamorphic_add_f64_neg_drop_to_defined_functions(
  mod : @lib.Module,
  leading : Bool,
) -> @lib.Module {
  metamorphic_add_unary_drop_to_defined_functions(mod, leading, [
    @lib.Instruction::f64_const(0.0),
    @lib.Instruction::f64_neg(),
    @lib.Instruction::drop(),
  ])
}

///|
fn metamorphic_add_f32_sqrt_drop_to_defined_functions(
  mod : @lib.Module,
  leading : Bool,
) -> @lib.Module {
  metamorphic_add_unary_drop_to_defined_functions(mod, leading, [
    @lib.Instruction::f32_const(0.0),
    @lib.Instruction::f32_sqrt(),
    @lib.Instruction::drop(),
  ])
}

///|
fn metamorphic_add_f64_sqrt_drop_to_defined_functions(
  mod : @lib.Module,
  leading : Bool,
) -> @lib.Module {
  metamorphic_add_unary_drop_to_defined_functions(mod, leading, [
    @lib.Instruction::f64_const(0.0),
    @lib.Instruction::f64_sqrt(),
    @lib.Instruction::drop(),
  ])
}

///|
fn metamorphic_add_f32_ceil_drop_to_defined_functions(
  mod : @lib.Module,
  leading : Bool,
) -> @lib.Module {
  metamorphic_add_unary_drop_to_defined_functions(mod, leading, [
    @lib.Instruction::f32_const(0.0),
    @lib.Instruction::f32_ceil(),
    @lib.Instruction::drop(),
  ])
}

///|
fn metamorphic_add_f32_floor_drop_to_defined_functions(
  mod : @lib.Module,
  leading : Bool,
) -> @lib.Module {
  metamorphic_add_unary_drop_to_defined_functions(mod, leading, [
    @lib.Instruction::f32_const(0.0),
    @lib.Instruction::f32_floor(),
    @lib.Instruction::drop(),
  ])
}

///|
fn metamorphic_add_f64_ceil_drop_to_defined_functions(
  mod : @lib.Module,
  leading : Bool,
) -> @lib.Module {
  metamorphic_add_unary_drop_to_defined_functions(mod, leading, [
    @lib.Instruction::f64_const(0.0),
    @lib.Instruction::f64_ceil(),
    @lib.Instruction::drop(),
  ])
}

///|
fn metamorphic_add_f64_floor_drop_to_defined_functions(
  mod : @lib.Module,
  leading : Bool,
) -> @lib.Module {
  metamorphic_add_unary_drop_to_defined_functions(mod, leading, [
    @lib.Instruction::f64_const(0.0),
    @lib.Instruction::f64_floor(),
    @lib.Instruction::drop(),
  ])
}

///|
fn metamorphic_add_f32_trunc_drop_to_defined_functions(
  mod : @lib.Module,
  leading : Bool,
) -> @lib.Module {
  metamorphic_add_unary_drop_to_defined_functions(mod, leading, [
    @lib.Instruction::f32_const(0.0),
    @lib.Instruction::f32_trunc(),
    @lib.Instruction::drop(),
  ])
}

///|
fn metamorphic_add_f32_nearest_drop_to_defined_functions(
  mod : @lib.Module,
  leading : Bool,
) -> @lib.Module {
  metamorphic_add_unary_drop_to_defined_functions(mod, leading, [
    @lib.Instruction::f32_const(0.0),
    @lib.Instruction::f32_nearest(),
    @lib.Instruction::drop(),
  ])
}

///|
fn metamorphic_add_f64_trunc_drop_to_defined_functions(
  mod : @lib.Module,
  leading : Bool,
) -> @lib.Module {
  metamorphic_add_unary_drop_to_defined_functions(mod, leading, [
    @lib.Instruction::f64_const(0.0),
    @lib.Instruction::f64_trunc(),
    @lib.Instruction::drop(),
  ])
}

///|
fn metamorphic_add_f64_nearest_drop_to_defined_functions(
  mod : @lib.Module,
  leading : Bool,
) -> @lib.Module {
  metamorphic_add_unary_drop_to_defined_functions(mod, leading, [
    @lib.Instruction::f64_const(0.0),
    @lib.Instruction::f64_nearest(),
    @lib.Instruction::drop(),
  ])
}

///|
fn metamorphic_add_i32_unary_drop_to_defined_functions(
  mod : @lib.Module,
  leading : Bool,
  unary : @lib.Instruction,
) -> @lib.Module {
  metamorphic_add_unary_drop_to_defined_functions(mod, leading, [
    @lib.Instruction::i32_const(0),
    unary,
    @lib.Instruction::drop(),
  ])
}

///|
fn metamorphic_add_i64_unary_drop_to_defined_functions(
  mod : @lib.Module,
  leading : Bool,
  unary : @lib.Instruction,
) -> @lib.Module {
  metamorphic_add_unary_drop_to_defined_functions(mod, leading, [
    @lib.Instruction::i64_const(0L),
    unary,
    @lib.Instruction::drop(),
  ])
}

///|
fn metamorphic_add_i32_binary_drop_to_defined_functions(
  mod : @lib.Module,
  leading : Bool,
  binary : @lib.Instruction,
) -> @lib.Module {
  metamorphic_add_unary_drop_to_defined_functions(mod, leading, [
    @lib.Instruction::i32_const(0),
    @lib.Instruction::i32_const(0),
    binary,
    @lib.Instruction::drop(),
  ])
}

///|
fn metamorphic_add_i64_binary_drop_to_defined_functions(
  mod : @lib.Module,
  leading : Bool,
  binary : @lib.Instruction,
) -> @lib.Module {
  metamorphic_add_unary_drop_to_defined_functions(mod, leading, [
    @lib.Instruction::i64_const(0L),
    @lib.Instruction::i64_const(0L),
    binary,
    @lib.Instruction::drop(),
  ])
}

///|
fn metamorphic_add_f32_binary_drop_to_defined_functions(
  mod : @lib.Module,
  leading : Bool,
  binary : @lib.Instruction,
) -> @lib.Module {
  metamorphic_add_unary_drop_to_defined_functions(mod, leading, [
    @lib.Instruction::f32_const(0.0),
    @lib.Instruction::f32_const(0.0),
    binary,
    @lib.Instruction::drop(),
  ])
}

///|
fn metamorphic_add_f64_binary_drop_to_defined_functions(
  mod : @lib.Module,
  leading : Bool,
  binary : @lib.Instruction,
) -> @lib.Module {
  metamorphic_add_unary_drop_to_defined_functions(mod, leading, [
    @lib.Instruction::f64_const(0.0),
    @lib.Instruction::f64_const(0.0),
    binary,
    @lib.Instruction::drop(),
  ])
}

///|
fn metamorphic_add_unary_drop_to_defined_functions(
  mod : @lib.Module,
  leading : Bool,
  debris : Array[@lib.Instruction],
) -> @lib.Module {
  let funcs = []
  match mod.code_sec {
    Some(@lib.CodeSec(existing)) =>
      for func in existing {
        match func {
          @lib.Func(locals, @lib.Expr(instrs)) => {
            let next_instrs = []
            if leading {
              for instr in debris {
                next_instrs.push(instr)
              }
            }
            for instr in instrs {
              next_instrs.push(instr)
            }
            if !leading {
              for instr in debris {
                next_instrs.push(instr)
              }
            }
            funcs.push(@lib.Func::new(locals, @lib.Expr::new(next_instrs)))
          }
        }
      }
    None => return mod
  }
  mod.with_code_sec(@lib.CodeSec::new(funcs))
}

///|
fn metamorphic_add_if_to_defined_functions(
  mod : @lib.Module,
  condition : Int,
  leading : Bool,
) -> @lib.Module {
  let funcs = []
  match mod.code_sec {
    Some(@lib.CodeSec(existing)) =>
      for func in existing {
        match func {
          @lib.Func(locals, @lib.Expr(instrs)) => {
            let if_instrs = [
              @lib.Instruction::i32_const(condition),
              @lib.Instruction::if_(@lib.BlockType::void_(), [], None),
            ]
            let next_instrs = []
            if leading {
              for instr in if_instrs {
                next_instrs.push(instr)
              }
            }
            for instr in instrs {
              next_instrs.push(instr)
            }
            if !leading {
              for instr in if_instrs {
                next_instrs.push(instr)
              }
            }
            funcs.push(@lib.Func::new(locals, @lib.Expr::new(next_instrs)))
          }
        }
      }
    None => return mod
  }
  mod.with_code_sec(@lib.CodeSec::new(funcs))
}

///|
fn metamorphic_add_leading_nop_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  let funcs = []
  match mod.code_sec {
    Some(@lib.CodeSec(existing)) =>
      for func in existing {
        match func {
          @lib.Func(locals, @lib.Expr(instrs)) => {
            let next_instrs = [@lib.Instruction::nop()]
            for instr in instrs {
              next_instrs.push(instr)
            }
            funcs.push(@lib.Func::new(locals, @lib.Expr::new(next_instrs)))
          }
        }
      }
    None => return mod
  }
  mod.with_code_sec(@lib.CodeSec::new(funcs))
}

///|
fn metamorphic_add_trailing_nop_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  let funcs = []
  match mod.code_sec {
    Some(@lib.CodeSec(existing)) =>
      for func in existing {
        match func {
          @lib.Func(locals, @lib.Expr(instrs)) => {
            let next_instrs = []
            for instr in instrs {
              next_instrs.push(instr)
            }
            next_instrs.push(@lib.Instruction::nop())
            funcs.push(@lib.Func::new(locals, @lib.Expr::new(next_instrs)))
          }
        }
      }
    None => return mod
  }
  mod.with_code_sec(@lib.CodeSec::new(funcs))
}

///|
fn metamorphic_add_leading_i32_const_drop_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  let funcs = []
  match mod.code_sec {
    Some(@lib.CodeSec(existing)) =>
      for func in existing {
        match func {
          @lib.Func(locals, @lib.Expr(instrs)) => {
            let next_instrs = [
              @lib.Instruction::i32_const(0),
              @lib.Instruction::drop(),
            ]
            for instr in instrs {
              next_instrs.push(instr)
            }
            funcs.push(@lib.Func::new(locals, @lib.Expr::new(next_instrs)))
          }
        }
      }
    None => return mod
  }
  mod.with_code_sec(@lib.CodeSec::new(funcs))
}

///|
fn metamorphic_add_trailing_i32_const_drop_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  let funcs = []
  match mod.code_sec {
    Some(@lib.CodeSec(existing)) =>
      for func in existing {
        match func {
          @lib.Func(locals, @lib.Expr(instrs)) => {
            let next_instrs = []
            for instr in instrs {
              next_instrs.push(instr)
            }
            next_instrs.push(@lib.Instruction::i32_const(0))
            next_instrs.push(@lib.Instruction::drop())
            funcs.push(@lib.Func::new(locals, @lib.Expr::new(next_instrs)))
          }
        }
      }
    None => return mod
  }
  mod.with_code_sec(@lib.CodeSec::new(funcs))
}

///|
fn metamorphic_add_trailing_empty_void_block_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  let funcs = []
  match mod.code_sec {
    Some(@lib.CodeSec(existing)) =>
      for func in existing {
        match func {
          @lib.Func(locals, @lib.Expr(instrs)) => {
            let next_instrs = []
            for instr in instrs {
              next_instrs.push(instr)
            }
            next_instrs.push(
              @lib.Instruction::block(
                @lib.BlockType::void_(),
                @lib.Expr::new([]),
              ),
            )
            funcs.push(@lib.Func::new(locals, @lib.Expr::new(next_instrs)))
          }
        }
      }
    None => return mod
  }
  mod.with_code_sec(@lib.CodeSec::new(funcs))
}

///|
fn metamorphic_add_leading_empty_void_block_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  let funcs = []
  match mod.code_sec {
    Some(@lib.CodeSec(existing)) =>
      for func in existing {
        match func {
          @lib.Func(locals, @lib.Expr(instrs)) => {
            let next_instrs = [
              @lib.Instruction::block(
                @lib.BlockType::void_(),
                @lib.Expr::new([]),
              ),
            ]
            for instr in instrs {
              next_instrs.push(instr)
            }
            funcs.push(@lib.Func::new(locals, @lib.Expr::new(next_instrs)))
          }
        }
      }
    None => return mod
  }
  mod.with_code_sec(@lib.CodeSec::new(funcs))
}

///|
fn metamorphic_add_leading_empty_void_loop_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  let funcs = []
  match mod.code_sec {
    Some(@lib.CodeSec(existing)) =>
      for func in existing {
        match func {
          @lib.Func(locals, @lib.Expr(instrs)) => {
            let next_instrs = [
              @lib.Instruction::loop_(
                @lib.BlockType::void_(),
                @lib.Expr::new([]),
              ),
            ]
            for instr in instrs {
              next_instrs.push(instr)
            }
            funcs.push(@lib.Func::new(locals, @lib.Expr::new(next_instrs)))
          }
        }
      }
    None => return mod
  }
  mod.with_code_sec(@lib.CodeSec::new(funcs))
}

///|
fn metamorphic_add_trailing_empty_void_loop_to_defined_functions(
  mod : @lib.Module,
) -> @lib.Module {
  let funcs = []
  match mod.code_sec {
    Some(@lib.CodeSec(existing)) =>
      for func in existing {
        match func {
          @lib.Func(locals, @lib.Expr(instrs)) => {
            let next_instrs = []
            for instr in instrs {
              next_instrs.push(instr)
            }
            next_instrs.push(
              @lib.Instruction::loop_(
                @lib.BlockType::void_(),
                @lib.Expr::new([]),
              ),
            )
            funcs.push(@lib.Func::new(locals, @lib.Expr::new(next_instrs)))
          }
        }
      }
    None => return mod
  }
  mod.with_code_sec(@lib.CodeSec::new(funcs))
}

///|
fn metamorphic_split_merge_local_declarations(mod : @lib.Module) -> @lib.Module {
  let funcs = []
  match mod.code_sec {
    Some(@lib.CodeSec(existing)) =>
      for func in existing {
        match func {
          @lib.Func(locals, expr) => {
            let runs = locals.runs()
            let next_runs : Array[@lib.LocalRun] = []
            let mut split_done = false
            for run in runs {
              if !split_done && run.count() > 1U {
                next_runs.push(@lib.LocalRun::new(1U, run.val_type()))
                next_runs.push(
                  @lib.LocalRun::new(run.count() - 1U, run.val_type()),
                )
                split_done = true
              } else {
                next_runs.push(run)
              }
            }
            funcs.push(
              @lib.Func::new(
                @lib.Locals::from_decl_runs_preserving_groups(next_runs),
                expr,
              ),
            )
          }
        }
      }
    None => return mod
  }
  mod.with_code_sec(@lib.CodeSec::new(funcs))
}

///|
fn metamorphic_reverse_custom_sections(mod : @lib.Module) -> @lib.Module {
  let custom_secs = []
  let mut index = mod.custom_secs.length()
  while index > 0 {
    index -= 1
    custom_secs.push(mod.custom_secs[index])
  }
  mod.with_custom_secs(custom_secs)
}

///|
fn metamorphic_export_name_to_string(name : @lib.Name) -> String {
  match name {
    @lib.Name(sv) => sv.to_owned()
  }
}

///|
fn metamorphic_unique_export_name(
  exports : Array[@lib.Export],
  base_name : String,
) -> @lib.Name {
  let mut suffix = 0
  let mut candidate = @lib.Name::from_string(base_name)
  while metamorphic_export_name_exists(exports, candidate) {
    suffix += 1
    candidate = @lib.Name::from_string("\{base_name}_\{suffix}")
  }
  candidate
}

///|
fn metamorphic_add_export_aliases(mod : @lib.Module) -> @lib.Module {
  let exports = []
  match mod.export_sec {
    Some(@lib.ExportSec(existing)) => {
      let mut alias_index = 0
      for export_ in existing {
        exports.push(export_)
      }
      for export_ in existing {
        match export_ {
          @lib.Export(_, extern_idx) => {
            let alias_name = metamorphic_unique_export_name(
              exports,
              "metamorphic_alias_\{alias_index}",
            )
            exports.push(@lib.Export::new(alias_name, extern_idx))
            alias_index += 1
          }
        }
      }
    }
    None => ()
  }
  mod.with_export_sec(@lib.ExportSec::new(exports))
}

///|
fn metamorphic_add_named_export_aliases(
  mod : @lib.Module,
  prefix : String,
  suffix : String,
) -> @lib.Module {
  let exports = []
  match mod.export_sec {
    Some(@lib.ExportSec(existing)) => {
      for export_ in existing {
        exports.push(export_)
      }
      for export_ in existing {
        match export_ {
          @lib.Export(name, extern_idx) => {
            let alias_name = metamorphic_unique_export_name(
              exports,
              "\{prefix}\{metamorphic_export_name_to_string(name)}\{suffix}",
            )
            exports.push(@lib.Export::new(alias_name, extern_idx))
          }
        }
      }
    }
    None => ()
  }
  mod.with_export_sec(@lib.ExportSec::new(exports))
}

///|
fn metamorphic_add_prefixed_export_aliases(mod : @lib.Module) -> @lib.Module {
  metamorphic_add_named_export_aliases(mod, "metamorphic_prefixed_alias_", "")
}

///|
fn metamorphic_add_suffixed_export_aliases(mod : @lib.Module) -> @lib.Module {
  metamorphic_add_named_export_aliases(mod, "", "_metamorphic_alias")
}

///|
fn metamorphic_export_name_exists(
  exports : Array[@lib.Export],
  candidate : @lib.Name,
) -> Bool {
  for export_ in exports {
    match export_ {
      @lib.Export(name, _) => if name == candidate { return true }
    }
  }
  false
}

///|
fn metamorphic_function_body_block_type(
  subtypes : Array[@lib.SubType],
  type_idx : @lib.TypeIdx,
) -> @lib.BlockType? {
  match type_idx {
    @lib.TypeIdx(i) =>
      match subtypes.get(i.reinterpret_as_int()) {
        Some(sub_type) =>
          match sub_type.get_comptype() {
            @lib.FuncCompType(_, []) => Some(@lib.BlockType::void_())
            @lib.FuncCompType(_, [result]) =>
              Some(@lib.BlockType::val_type(result))
            _ => None
          }
        None => None
      }
    @lib.RecIdx(_) => None
  }
}

///|
fn metamorphic_wrap_defined_function_bodies_in_identity_block(
  mod : @lib.Module,
) -> @lib.Module {
  let subtypes = metamorphic_flatten_types(mod)
  let type_idxs = match mod.func_sec {
    Some(@lib.FuncSec(existing)) => existing
    None => return mod
  }
  let funcs = []
  match mod.code_sec {
    Some(@lib.CodeSec(existing)) =>
      for i = 0; i < existing.length(); i = i + 1 {
        match existing[i] {
          @lib.Func(locals, expr) => {
            let block_type = match type_idxs.get(i) {
              Some(type_idx) =>
                metamorphic_function_body_block_type(subtypes, type_idx)
              None => None
            }
            match block_type {
              Some(bt) =>
                funcs.push(
                  @lib.Func::new(
                    locals,
                    @lib.Expr::new([@lib.Instruction::block(bt, expr)]),
                  ),
                )
              None => funcs.push(@lib.Func::new(locals, expr))
            }
          }
        }
      }
    None => return mod
  }
  mod.with_code_sec(@lib.CodeSec::new(funcs))
}

///|
fn metamorphic_add_unused_empty_function(mod : @lib.Module) -> @lib.Module {
  let types = []
  match mod.type_sec {
    Some(@lib.TypeSec(existing)) =>
      for rec_type in existing {
        types.push(rec_type)
      }
    None => ()
  }
  let empty_func_type_idx = @lib.TypeIdx::new(
    metamorphic_count_flat_types(types).reinterpret_as_uint(),
  )
  types.push(
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
  )
  let func_type_idxs = []
  match mod.func_sec {
    Some(@lib.FuncSec(existing)) =>
      for type_idx in existing {
        func_type_idxs.push(type_idx)
      }
    None => ()
  }
  func_type_idxs.push(empty_func_type_idx)
  let funcs = []
  match mod.code_sec {
    Some(@lib.CodeSec(existing)) =>
      for func in existing {
        funcs.push(func)
      }
    None => ()
  }
  funcs.push(@lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])))
  mod
  .with_type_sec(@lib.TypeSec::new(types))
  .with_func_sec(@lib.FuncSec::new(func_type_idxs))
  .with_code_sec(@lib.CodeSec::new(funcs))
}

///|
fn metamorphic_valid_transforms() -> Array[MetamorphicValidTransform] {
  [
    AddNonNameCustomSection,
    AddLeadingNonNameCustomSection,
    AddCustomSectionStress,
    AddModuleNameSection,
    AddUnusedPassiveDataSegment,
    AddUnusedImmutableI32Global,
    AddUnusedEmptyFunction,
    AddUnusedEmptyFunctionType,
    AddDuplicateEquivalentFunctionType,
    AddUnusedFuncrefTable,
    AddUnusedPassiveFuncrefElementSegment,
    AddFunctionNamesSection,
    AddLocalNamesSection,
    AddLabelNamesSection,
    AddTypeNamesSection,
    AddGlobalNamesSection,
    AddTableNamesSection,
    AddMemoryNamesSection,
    AddDataNamesSection,
    AddElemNamesSection,
    AddTagNamesSection,
    AddFieldNamesSection,
    AddUnusedI32LocalToDefinedFunctions,
    AddUnusedNumericLocalsToDefinedFunctions,
    AddUnusedReferenceLocalsToDefinedFunctions,
    AddUnusedV128LocalToDefinedFunctions,
    AddUnusedGcReferenceLocalsToDefinedFunctions,
    AddLeadingRefNullDropToDefinedFunctions,
    AddTrailingRefNullDropToDefinedFunctions,
    AddLeadingI64ConstDropToDefinedFunctions,
    AddTrailingI64ConstDropToDefinedFunctions,
    AddLeadingF32ConstDropToDefinedFunctions,
    AddTrailingF32ConstDropToDefinedFunctions,
    AddLeadingF64ConstDropToDefinedFunctions,
    AddTrailingF64ConstDropToDefinedFunctions,
    AddLeadingFalseIfToDefinedFunctions,
    AddTrailingFalseIfToDefinedFunctions,
    AddLeadingTrueIfToDefinedFunctions,
    AddTrailingTrueIfToDefinedFunctions,
    AddLeadingI32EqzDropToDefinedFunctions,
    AddTrailingI32EqzDropToDefinedFunctions,
    AddLeadingI64EqzDropToDefinedFunctions,
    AddTrailingI64EqzDropToDefinedFunctions,
    AddLeadingI32EqDropToDefinedFunctions,
    AddTrailingI32EqDropToDefinedFunctions,
    AddLeadingI32NeDropToDefinedFunctions,
    AddTrailingI32NeDropToDefinedFunctions,
    AddLeadingI64EqDropToDefinedFunctions,
    AddTrailingI64EqDropToDefinedFunctions,
    AddLeadingI64NeDropToDefinedFunctions,
    AddTrailingI64NeDropToDefinedFunctions,
    AddLeadingI32LtSDropToDefinedFunctions,
    AddTrailingI32LtSDropToDefinedFunctions,
    AddLeadingI32GtSDropToDefinedFunctions,
    AddTrailingI32GtSDropToDefinedFunctions,
    AddLeadingI64LtSDropToDefinedFunctions,
    AddTrailingI64LtSDropToDefinedFunctions,
    AddLeadingI64GtSDropToDefinedFunctions,
    AddTrailingI64GtSDropToDefinedFunctions,
    AddLeadingI32LeSDropToDefinedFunctions,
    AddTrailingI32LeSDropToDefinedFunctions,
    AddLeadingI32GeSDropToDefinedFunctions,
    AddTrailingI32GeSDropToDefinedFunctions,
    AddLeadingI64LeSDropToDefinedFunctions,
    AddTrailingI64LeSDropToDefinedFunctions,
    AddLeadingI64GeSDropToDefinedFunctions,
    AddTrailingI64GeSDropToDefinedFunctions,
    AddLeadingI32LtUDropToDefinedFunctions,
    AddTrailingI32LtUDropToDefinedFunctions,
    AddLeadingI32GtUDropToDefinedFunctions,
    AddTrailingI32GtUDropToDefinedFunctions,
    AddLeadingI64LtUDropToDefinedFunctions,
    AddTrailingI64LtUDropToDefinedFunctions,
    AddLeadingI64GtUDropToDefinedFunctions,
    AddTrailingI64GtUDropToDefinedFunctions,
    AddLeadingI32LeUDropToDefinedFunctions,
    AddTrailingI32LeUDropToDefinedFunctions,
    AddLeadingI32GeUDropToDefinedFunctions,
    AddTrailingI32GeUDropToDefinedFunctions,
    AddLeadingI64LeUDropToDefinedFunctions,
    AddTrailingI64LeUDropToDefinedFunctions,
    AddLeadingI64GeUDropToDefinedFunctions,
    AddTrailingI64GeUDropToDefinedFunctions,
    AddLeadingI32AndDropToDefinedFunctions,
    AddTrailingI32AndDropToDefinedFunctions,
    AddLeadingI32OrDropToDefinedFunctions,
    AddTrailingI32OrDropToDefinedFunctions,
    AddLeadingI32XorDropToDefinedFunctions,
    AddTrailingI32XorDropToDefinedFunctions,
    AddLeadingI64AndDropToDefinedFunctions,
    AddTrailingI64AndDropToDefinedFunctions,
    AddLeadingI64OrDropToDefinedFunctions,
    AddTrailingI64OrDropToDefinedFunctions,
    AddLeadingI64XorDropToDefinedFunctions,
    AddTrailingI64XorDropToDefinedFunctions,
    AddLeadingI32ClzDropToDefinedFunctions,
    AddTrailingI32ClzDropToDefinedFunctions,
    AddLeadingI32CtzDropToDefinedFunctions,
    AddTrailingI32CtzDropToDefinedFunctions,
    AddLeadingI32PopcntDropToDefinedFunctions,
    AddTrailingI32PopcntDropToDefinedFunctions,
    AddLeadingI64ClzDropToDefinedFunctions,
    AddTrailingI64ClzDropToDefinedFunctions,
    AddLeadingI64CtzDropToDefinedFunctions,
    AddTrailingI64CtzDropToDefinedFunctions,
    AddLeadingI64PopcntDropToDefinedFunctions,
    AddTrailingI64PopcntDropToDefinedFunctions,
    AddLeadingI32WrapI64DropToDefinedFunctions,
    AddTrailingI32WrapI64DropToDefinedFunctions,
    AddLeadingI64ExtendI32SDropToDefinedFunctions,
    AddTrailingI64ExtendI32SDropToDefinedFunctions,
    AddLeadingI64ExtendI32UDropToDefinedFunctions,
    AddTrailingI64ExtendI32UDropToDefinedFunctions,
    AddLeadingF32ConvertI32SDropToDefinedFunctions,
    AddTrailingF32ConvertI32SDropToDefinedFunctions,
    AddLeadingF32ConvertI32UDropToDefinedFunctions,
    AddTrailingF32ConvertI32UDropToDefinedFunctions,
    AddLeadingF32ConvertI64SDropToDefinedFunctions,
    AddTrailingF32ConvertI64SDropToDefinedFunctions,
    AddLeadingF32ConvertI64UDropToDefinedFunctions,
    AddTrailingF32ConvertI64UDropToDefinedFunctions,
    AddLeadingI32ShlDropToDefinedFunctions,
    AddTrailingI32ShlDropToDefinedFunctions,
    AddLeadingI32ShrSDropToDefinedFunctions,
    AddTrailingI32ShrSDropToDefinedFunctions,
    AddLeadingI32ShrUDropToDefinedFunctions,
    AddTrailingI32ShrUDropToDefinedFunctions,
    AddLeadingI64ShlDropToDefinedFunctions,
    AddTrailingI64ShlDropToDefinedFunctions,
    AddLeadingI64ShrSDropToDefinedFunctions,
    AddTrailingI64ShrSDropToDefinedFunctions,
    AddLeadingI64ShrUDropToDefinedFunctions,
    AddTrailingI64ShrUDropToDefinedFunctions,
    AddLeadingI32RotlDropToDefinedFunctions,
    AddTrailingI32RotlDropToDefinedFunctions,
    AddLeadingI32RotrDropToDefinedFunctions,
    AddTrailingI32RotrDropToDefinedFunctions,
    AddLeadingI64RotlDropToDefinedFunctions,
    AddTrailingI64RotlDropToDefinedFunctions,
    AddLeadingI64RotrDropToDefinedFunctions,
    AddTrailingI64RotrDropToDefinedFunctions,
    AddLeadingF32AbsDropToDefinedFunctions,
    AddTrailingF32AbsDropToDefinedFunctions,
    AddLeadingF64AbsDropToDefinedFunctions,
    AddTrailingF64AbsDropToDefinedFunctions,
    AddLeadingF32NegDropToDefinedFunctions,
    AddTrailingF32NegDropToDefinedFunctions,
    AddLeadingF64NegDropToDefinedFunctions,
    AddTrailingF64NegDropToDefinedFunctions,
    AddLeadingF32SqrtDropToDefinedFunctions,
    AddTrailingF32SqrtDropToDefinedFunctions,
    AddLeadingF64SqrtDropToDefinedFunctions,
    AddTrailingF64SqrtDropToDefinedFunctions,
    AddLeadingF32CeilDropToDefinedFunctions,
    AddTrailingF32CeilDropToDefinedFunctions,
    AddLeadingF32FloorDropToDefinedFunctions,
    AddTrailingF32FloorDropToDefinedFunctions,
    AddLeadingF64CeilDropToDefinedFunctions,
    AddTrailingF64CeilDropToDefinedFunctions,
    AddLeadingF64FloorDropToDefinedFunctions,
    AddTrailingF64FloorDropToDefinedFunctions,
    AddLeadingF32TruncDropToDefinedFunctions,
    AddTrailingF32TruncDropToDefinedFunctions,
    AddLeadingF32NearestDropToDefinedFunctions,
    AddTrailingF32NearestDropToDefinedFunctions,
    AddLeadingF64TruncDropToDefinedFunctions,
    AddTrailingF64TruncDropToDefinedFunctions,
    AddLeadingF64NearestDropToDefinedFunctions,
    AddTrailingF64NearestDropToDefinedFunctions,
    AddLeadingF32AddDropToDefinedFunctions,
    AddTrailingF32AddDropToDefinedFunctions,
    AddLeadingF32SubDropToDefinedFunctions,
    AddTrailingF32SubDropToDefinedFunctions,
    AddLeadingF64AddDropToDefinedFunctions,
    AddTrailingF64AddDropToDefinedFunctions,
    AddLeadingF64SubDropToDefinedFunctions,
    AddTrailingF64SubDropToDefinedFunctions,
    AddLeadingF32MulDropToDefinedFunctions,
    AddTrailingF32MulDropToDefinedFunctions,
    AddLeadingF32DivDropToDefinedFunctions,
    AddTrailingF32DivDropToDefinedFunctions,
    AddLeadingF64MulDropToDefinedFunctions,
    AddTrailingF64MulDropToDefinedFunctions,
    AddLeadingF64DivDropToDefinedFunctions,
    AddTrailingF64DivDropToDefinedFunctions,
    AddLeadingF32MinDropToDefinedFunctions,
    AddTrailingF32MinDropToDefinedFunctions,
    AddLeadingF32MaxDropToDefinedFunctions,
    AddTrailingF32MaxDropToDefinedFunctions,
    AddLeadingF64MinDropToDefinedFunctions,
    AddTrailingF64MinDropToDefinedFunctions,
    AddLeadingF64MaxDropToDefinedFunctions,
    AddTrailingF64MaxDropToDefinedFunctions,
    AddLeadingF32CopysignDropToDefinedFunctions,
    AddTrailingF32CopysignDropToDefinedFunctions,
    AddLeadingF64CopysignDropToDefinedFunctions,
    AddTrailingF64CopysignDropToDefinedFunctions,
    AddLeadingF32EqDropToDefinedFunctions,
    AddTrailingF32EqDropToDefinedFunctions,
    AddLeadingF32NeDropToDefinedFunctions,
    AddTrailingF32NeDropToDefinedFunctions,
    AddLeadingF64EqDropToDefinedFunctions,
    AddTrailingF64EqDropToDefinedFunctions,
    AddLeadingF64NeDropToDefinedFunctions,
    AddTrailingF64NeDropToDefinedFunctions,
    AddLeadingF32LtDropToDefinedFunctions,
    AddTrailingF32LtDropToDefinedFunctions,
    AddLeadingF32GtDropToDefinedFunctions,
    AddTrailingF32GtDropToDefinedFunctions,
    AddLeadingF64LtDropToDefinedFunctions,
    AddTrailingF64LtDropToDefinedFunctions,
    AddLeadingF64GtDropToDefinedFunctions,
    AddTrailingF64GtDropToDefinedFunctions,
    AddLeadingF32LeDropToDefinedFunctions,
    AddTrailingF32LeDropToDefinedFunctions,
    AddLeadingF32GeDropToDefinedFunctions,
    AddTrailingF32GeDropToDefinedFunctions,
    AddLeadingF64LeDropToDefinedFunctions,
    AddTrailingF64LeDropToDefinedFunctions,
    AddLeadingF64GeDropToDefinedFunctions,
    AddTrailingF64GeDropToDefinedFunctions,
    AddLeadingNopToDefinedFunctions,
    AddTrailingNopToDefinedFunctions,
    AddLeadingI32ConstDropToDefinedFunctions,
    AddTrailingI32ConstDropToDefinedFunctions,
    AddTrailingEmptyVoidBlockToDefinedFunctions,
    AddLeadingEmptyVoidBlockToDefinedFunctions,
    AddLeadingEmptyVoidLoopToDefinedFunctions,
    AddTrailingEmptyVoidLoopToDefinedFunctions,
    WrapDefinedFunctionBodiesInIdentityBlock,
    SplitMergeLocalDeclarations,
    AddExportAliases,
    AddPrefixedExportAliases,
    AddSuffixedExportAliases,
    ReverseCustomSections,
  ]
}

///|
pub fn metamorphic_apply_transform(
  mod : @lib.Module,
  transform : MetamorphicValidTransform,
) -> Result[MetamorphicValidTransformResult, String] {
  let transformed = match transform {
    AddNonNameCustomSection => metamorphic_add_non_name_custom_section(mod)
    AddLeadingNonNameCustomSection =>
      metamorphic_add_leading_non_name_custom_section(mod)
    AddCustomSectionStress => metamorphic_add_custom_section_stress(mod)
    AddModuleNameSection => metamorphic_add_module_name_section(mod)
    AddUnusedPassiveDataSegment =>
      metamorphic_add_unused_passive_data_segment(mod)
    AddUnusedImmutableI32Global =>
      metamorphic_add_unused_immutable_i32_global(mod)
    AddUnusedEmptyFunction => metamorphic_add_unused_empty_function(mod)
    AddUnusedEmptyFunctionType =>
      metamorphic_add_unused_empty_function_type(mod)
    AddDuplicateEquivalentFunctionType =>
      metamorphic_add_duplicate_equivalent_function_type(mod)
    AddUnusedFuncrefTable => metamorphic_add_unused_funcref_table(mod)
    AddUnusedPassiveFuncrefElementSegment =>
      metamorphic_add_unused_passive_funcref_element_segment(mod)
    AddFunctionNamesSection => metamorphic_add_function_names_section(mod)
    AddLocalNamesSection => metamorphic_add_local_names_section(mod)
    AddLabelNamesSection => metamorphic_add_label_names_section(mod)
    AddTypeNamesSection => metamorphic_add_type_names_section(mod)
    AddGlobalNamesSection => metamorphic_add_global_names_section(mod)
    AddTableNamesSection => metamorphic_add_table_names_section(mod)
    AddMemoryNamesSection => metamorphic_add_memory_names_section(mod)
    AddDataNamesSection => metamorphic_add_data_names_section(mod)
    AddElemNamesSection => metamorphic_add_elem_names_section(mod)
    AddTagNamesSection => metamorphic_add_tag_names_section(mod)
    AddFieldNamesSection => metamorphic_add_field_names_section(mod)
    AddUnusedI32LocalToDefinedFunctions =>
      metamorphic_add_unused_i32_local_to_defined_functions(mod)
    AddUnusedNumericLocalsToDefinedFunctions =>
      metamorphic_add_unused_numeric_locals_to_defined_functions(mod)
    AddUnusedReferenceLocalsToDefinedFunctions =>
      metamorphic_add_unused_reference_locals_to_defined_functions(mod)
    AddUnusedV128LocalToDefinedFunctions =>
      metamorphic_add_unused_v128_local_to_defined_functions(mod)
    AddUnusedGcReferenceLocalsToDefinedFunctions =>
      metamorphic_add_unused_gc_reference_locals_to_defined_functions(mod)
    AddLeadingRefNullDropToDefinedFunctions =>
      metamorphic_add_leading_ref_null_drop_to_defined_functions(mod)
    AddTrailingRefNullDropToDefinedFunctions =>
      metamorphic_add_trailing_ref_null_drop_to_defined_functions(mod)
    AddLeadingI64ConstDropToDefinedFunctions =>
      metamorphic_add_leading_i64_const_drop_to_defined_functions(mod)
    AddTrailingI64ConstDropToDefinedFunctions =>
      metamorphic_add_trailing_i64_const_drop_to_defined_functions(mod)
    AddLeadingF32ConstDropToDefinedFunctions =>
      metamorphic_add_leading_f32_const_drop_to_defined_functions(mod)
    AddTrailingF32ConstDropToDefinedFunctions =>
      metamorphic_add_trailing_f32_const_drop_to_defined_functions(mod)
    AddLeadingF64ConstDropToDefinedFunctions =>
      metamorphic_add_leading_f64_const_drop_to_defined_functions(mod)
    AddTrailingF64ConstDropToDefinedFunctions =>
      metamorphic_add_trailing_f64_const_drop_to_defined_functions(mod)
    AddLeadingFalseIfToDefinedFunctions =>
      metamorphic_add_leading_false_if_to_defined_functions(mod)
    AddTrailingFalseIfToDefinedFunctions =>
      metamorphic_add_trailing_false_if_to_defined_functions(mod)
    AddLeadingTrueIfToDefinedFunctions =>
      metamorphic_add_leading_true_if_to_defined_functions(mod)
    AddTrailingTrueIfToDefinedFunctions =>
      metamorphic_add_trailing_true_if_to_defined_functions(mod)
    AddLeadingI32EqzDropToDefinedFunctions =>
      metamorphic_add_leading_i32_eqz_drop_to_defined_functions(mod)
    AddTrailingI32EqzDropToDefinedFunctions =>
      metamorphic_add_trailing_i32_eqz_drop_to_defined_functions(mod)
    AddLeadingI64EqzDropToDefinedFunctions =>
      metamorphic_add_leading_i64_eqz_drop_to_defined_functions(mod)
    AddTrailingI64EqzDropToDefinedFunctions =>
      metamorphic_add_trailing_i64_eqz_drop_to_defined_functions(mod)
    AddLeadingI32EqDropToDefinedFunctions =>
      metamorphic_add_i32_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::i32_eq(),
      )
    AddTrailingI32EqDropToDefinedFunctions =>
      metamorphic_add_i32_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::i32_eq(),
      )
    AddLeadingI32NeDropToDefinedFunctions =>
      metamorphic_add_i32_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::i32_ne(),
      )
    AddTrailingI32NeDropToDefinedFunctions =>
      metamorphic_add_i32_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::i32_ne(),
      )
    AddLeadingI64EqDropToDefinedFunctions =>
      metamorphic_add_i64_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::i64_eq(),
      )
    AddTrailingI64EqDropToDefinedFunctions =>
      metamorphic_add_i64_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::i64_eq(),
      )
    AddLeadingI64NeDropToDefinedFunctions =>
      metamorphic_add_i64_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::i64_ne(),
      )
    AddTrailingI64NeDropToDefinedFunctions =>
      metamorphic_add_i64_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::i64_ne(),
      )
    AddLeadingI32LtSDropToDefinedFunctions =>
      metamorphic_add_i32_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::i32_lt_s(),
      )
    AddTrailingI32LtSDropToDefinedFunctions =>
      metamorphic_add_i32_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::i32_lt_s(),
      )
    AddLeadingI32GtSDropToDefinedFunctions =>
      metamorphic_add_i32_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::i32_gt_s(),
      )
    AddTrailingI32GtSDropToDefinedFunctions =>
      metamorphic_add_i32_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::i32_gt_s(),
      )
    AddLeadingI64LtSDropToDefinedFunctions =>
      metamorphic_add_i64_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::i64_lt_s(),
      )
    AddTrailingI64LtSDropToDefinedFunctions =>
      metamorphic_add_i64_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::i64_lt_s(),
      )
    AddLeadingI64GtSDropToDefinedFunctions =>
      metamorphic_add_i64_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::i64_gt_s(),
      )
    AddTrailingI64GtSDropToDefinedFunctions =>
      metamorphic_add_i64_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::i64_gt_s(),
      )
    AddLeadingI32LeSDropToDefinedFunctions =>
      metamorphic_add_i32_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::i32_le_s(),
      )
    AddTrailingI32LeSDropToDefinedFunctions =>
      metamorphic_add_i32_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::i32_le_s(),
      )
    AddLeadingI32GeSDropToDefinedFunctions =>
      metamorphic_add_i32_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::i32_ge_s(),
      )
    AddTrailingI32GeSDropToDefinedFunctions =>
      metamorphic_add_i32_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::i32_ge_s(),
      )
    AddLeadingI64LeSDropToDefinedFunctions =>
      metamorphic_add_i64_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::i64_le_s(),
      )
    AddTrailingI64LeSDropToDefinedFunctions =>
      metamorphic_add_i64_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::i64_le_s(),
      )
    AddLeadingI64GeSDropToDefinedFunctions =>
      metamorphic_add_i64_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::i64_ge_s(),
      )
    AddTrailingI64GeSDropToDefinedFunctions =>
      metamorphic_add_i64_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::i64_ge_s(),
      )
    AddLeadingI32LtUDropToDefinedFunctions =>
      metamorphic_add_i32_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::i32_lt_u(),
      )
    AddTrailingI32LtUDropToDefinedFunctions =>
      metamorphic_add_i32_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::i32_lt_u(),
      )
    AddLeadingI32GtUDropToDefinedFunctions =>
      metamorphic_add_i32_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::i32_gt_u(),
      )
    AddTrailingI32GtUDropToDefinedFunctions =>
      metamorphic_add_i32_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::i32_gt_u(),
      )
    AddLeadingI64LtUDropToDefinedFunctions =>
      metamorphic_add_i64_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::i64_lt_u(),
      )
    AddTrailingI64LtUDropToDefinedFunctions =>
      metamorphic_add_i64_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::i64_lt_u(),
      )
    AddLeadingI64GtUDropToDefinedFunctions =>
      metamorphic_add_i64_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::i64_gt_u(),
      )
    AddTrailingI64GtUDropToDefinedFunctions =>
      metamorphic_add_i64_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::i64_gt_u(),
      )
    AddLeadingI32LeUDropToDefinedFunctions =>
      metamorphic_add_i32_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::i32_le_u(),
      )
    AddTrailingI32LeUDropToDefinedFunctions =>
      metamorphic_add_i32_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::i32_le_u(),
      )
    AddLeadingI32GeUDropToDefinedFunctions =>
      metamorphic_add_i32_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::i32_ge_u(),
      )
    AddTrailingI32GeUDropToDefinedFunctions =>
      metamorphic_add_i32_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::i32_ge_u(),
      )
    AddLeadingI64LeUDropToDefinedFunctions =>
      metamorphic_add_i64_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::i64_le_u(),
      )
    AddTrailingI64LeUDropToDefinedFunctions =>
      metamorphic_add_i64_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::i64_le_u(),
      )
    AddLeadingI64GeUDropToDefinedFunctions =>
      metamorphic_add_i64_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::i64_ge_u(),
      )
    AddTrailingI64GeUDropToDefinedFunctions =>
      metamorphic_add_i64_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::i64_ge_u(),
      )
    AddLeadingI32AndDropToDefinedFunctions =>
      metamorphic_add_i32_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::i32_and(),
      )
    AddTrailingI32AndDropToDefinedFunctions =>
      metamorphic_add_i32_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::i32_and(),
      )
    AddLeadingI32OrDropToDefinedFunctions =>
      metamorphic_add_i32_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::i32_or(),
      )
    AddTrailingI32OrDropToDefinedFunctions =>
      metamorphic_add_i32_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::i32_or(),
      )
    AddLeadingI32XorDropToDefinedFunctions =>
      metamorphic_add_i32_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::i32_xor(),
      )
    AddTrailingI32XorDropToDefinedFunctions =>
      metamorphic_add_i32_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::i32_xor(),
      )
    AddLeadingI64AndDropToDefinedFunctions =>
      metamorphic_add_i64_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::i64_and(),
      )
    AddTrailingI64AndDropToDefinedFunctions =>
      metamorphic_add_i64_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::i64_and(),
      )
    AddLeadingI64OrDropToDefinedFunctions =>
      metamorphic_add_i64_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::i64_or(),
      )
    AddTrailingI64OrDropToDefinedFunctions =>
      metamorphic_add_i64_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::i64_or(),
      )
    AddLeadingI64XorDropToDefinedFunctions =>
      metamorphic_add_i64_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::i64_xor(),
      )
    AddTrailingI64XorDropToDefinedFunctions =>
      metamorphic_add_i64_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::i64_xor(),
      )
    AddLeadingI32ClzDropToDefinedFunctions =>
      metamorphic_add_i32_unary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::i32_clz(),
      )
    AddTrailingI32ClzDropToDefinedFunctions =>
      metamorphic_add_i32_unary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::i32_clz(),
      )
    AddLeadingI32CtzDropToDefinedFunctions =>
      metamorphic_add_i32_unary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::i32_ctz(),
      )
    AddTrailingI32CtzDropToDefinedFunctions =>
      metamorphic_add_i32_unary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::i32_ctz(),
      )
    AddLeadingI32PopcntDropToDefinedFunctions =>
      metamorphic_add_i32_unary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::i32_popcnt(),
      )
    AddTrailingI32PopcntDropToDefinedFunctions =>
      metamorphic_add_i32_unary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::i32_popcnt(),
      )
    AddLeadingI64ClzDropToDefinedFunctions =>
      metamorphic_add_i64_unary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::i64_clz(),
      )
    AddTrailingI64ClzDropToDefinedFunctions =>
      metamorphic_add_i64_unary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::i64_clz(),
      )
    AddLeadingI64CtzDropToDefinedFunctions =>
      metamorphic_add_i64_unary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::i64_ctz(),
      )
    AddTrailingI64CtzDropToDefinedFunctions =>
      metamorphic_add_i64_unary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::i64_ctz(),
      )
    AddLeadingI64PopcntDropToDefinedFunctions =>
      metamorphic_add_i64_unary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::i64_popcnt(),
      )
    AddTrailingI64PopcntDropToDefinedFunctions =>
      metamorphic_add_i64_unary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::i64_popcnt(),
      )
    AddLeadingI32WrapI64DropToDefinedFunctions =>
      metamorphic_add_i64_unary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::i32_wrap_i64(),
      )
    AddTrailingI32WrapI64DropToDefinedFunctions =>
      metamorphic_add_i64_unary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::i32_wrap_i64(),
      )
    AddLeadingI64ExtendI32SDropToDefinedFunctions =>
      metamorphic_add_i32_unary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::i64_extend_i32s(),
      )
    AddTrailingI64ExtendI32SDropToDefinedFunctions =>
      metamorphic_add_i32_unary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::i64_extend_i32s(),
      )
    AddLeadingI64ExtendI32UDropToDefinedFunctions =>
      metamorphic_add_i32_unary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::i64_extend_i32u(),
      )
    AddTrailingI64ExtendI32UDropToDefinedFunctions =>
      metamorphic_add_i32_unary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::i64_extend_i32u(),
      )
    AddLeadingF32ConvertI32SDropToDefinedFunctions =>
      metamorphic_add_i32_unary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::f32_convert_i32s(),
      )
    AddTrailingF32ConvertI32SDropToDefinedFunctions =>
      metamorphic_add_i32_unary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::f32_convert_i32s(),
      )
    AddLeadingF32ConvertI32UDropToDefinedFunctions =>
      metamorphic_add_i32_unary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::f32_convert_i32u(),
      )
    AddTrailingF32ConvertI32UDropToDefinedFunctions =>
      metamorphic_add_i32_unary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::f32_convert_i32u(),
      )
    AddLeadingF32ConvertI64SDropToDefinedFunctions =>
      metamorphic_add_i64_unary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::f32_convert_i64s(),
      )
    AddTrailingF32ConvertI64SDropToDefinedFunctions =>
      metamorphic_add_i64_unary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::f32_convert_i64s(),
      )
    AddLeadingF32ConvertI64UDropToDefinedFunctions =>
      metamorphic_add_i64_unary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::f32_convert_i64u(),
      )
    AddTrailingF32ConvertI64UDropToDefinedFunctions =>
      metamorphic_add_i64_unary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::f32_convert_i64u(),
      )
    AddLeadingI32ShlDropToDefinedFunctions =>
      metamorphic_add_i32_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::i32_shl(),
      )
    AddTrailingI32ShlDropToDefinedFunctions =>
      metamorphic_add_i32_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::i32_shl(),
      )
    AddLeadingI32ShrSDropToDefinedFunctions =>
      metamorphic_add_i32_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::i32_shr_s(),
      )
    AddTrailingI32ShrSDropToDefinedFunctions =>
      metamorphic_add_i32_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::i32_shr_s(),
      )
    AddLeadingI32ShrUDropToDefinedFunctions =>
      metamorphic_add_i32_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::i32_shr_u(),
      )
    AddTrailingI32ShrUDropToDefinedFunctions =>
      metamorphic_add_i32_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::i32_shr_u(),
      )
    AddLeadingI64ShlDropToDefinedFunctions =>
      metamorphic_add_i64_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::i64_shl(),
      )
    AddTrailingI64ShlDropToDefinedFunctions =>
      metamorphic_add_i64_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::i64_shl(),
      )
    AddLeadingI64ShrSDropToDefinedFunctions =>
      metamorphic_add_i64_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::i64_shr_s(),
      )
    AddTrailingI64ShrSDropToDefinedFunctions =>
      metamorphic_add_i64_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::i64_shr_s(),
      )
    AddLeadingI64ShrUDropToDefinedFunctions =>
      metamorphic_add_i64_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::i64_shr_u(),
      )
    AddTrailingI64ShrUDropToDefinedFunctions =>
      metamorphic_add_i64_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::i64_shr_u(),
      )
    AddLeadingI32RotlDropToDefinedFunctions =>
      metamorphic_add_i32_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::i32_rotl(),
      )
    AddTrailingI32RotlDropToDefinedFunctions =>
      metamorphic_add_i32_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::i32_rotl(),
      )
    AddLeadingI32RotrDropToDefinedFunctions =>
      metamorphic_add_i32_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::i32_rotr(),
      )
    AddTrailingI32RotrDropToDefinedFunctions =>
      metamorphic_add_i32_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::i32_rotr(),
      )
    AddLeadingI64RotlDropToDefinedFunctions =>
      metamorphic_add_i64_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::i64_rotl(),
      )
    AddTrailingI64RotlDropToDefinedFunctions =>
      metamorphic_add_i64_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::i64_rotl(),
      )
    AddLeadingI64RotrDropToDefinedFunctions =>
      metamorphic_add_i64_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::i64_rotr(),
      )
    AddTrailingI64RotrDropToDefinedFunctions =>
      metamorphic_add_i64_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::i64_rotr(),
      )
    AddLeadingF32AbsDropToDefinedFunctions =>
      metamorphic_add_leading_f32_abs_drop_to_defined_functions(mod)
    AddTrailingF32AbsDropToDefinedFunctions =>
      metamorphic_add_trailing_f32_abs_drop_to_defined_functions(mod)
    AddLeadingF64AbsDropToDefinedFunctions =>
      metamorphic_add_leading_f64_abs_drop_to_defined_functions(mod)
    AddTrailingF64AbsDropToDefinedFunctions =>
      metamorphic_add_trailing_f64_abs_drop_to_defined_functions(mod)
    AddLeadingF32NegDropToDefinedFunctions =>
      metamorphic_add_leading_f32_neg_drop_to_defined_functions(mod)
    AddTrailingF32NegDropToDefinedFunctions =>
      metamorphic_add_trailing_f32_neg_drop_to_defined_functions(mod)
    AddLeadingF64NegDropToDefinedFunctions =>
      metamorphic_add_leading_f64_neg_drop_to_defined_functions(mod)
    AddTrailingF64NegDropToDefinedFunctions =>
      metamorphic_add_trailing_f64_neg_drop_to_defined_functions(mod)
    AddLeadingF32SqrtDropToDefinedFunctions =>
      metamorphic_add_leading_f32_sqrt_drop_to_defined_functions(mod)
    AddTrailingF32SqrtDropToDefinedFunctions =>
      metamorphic_add_trailing_f32_sqrt_drop_to_defined_functions(mod)
    AddLeadingF64SqrtDropToDefinedFunctions =>
      metamorphic_add_leading_f64_sqrt_drop_to_defined_functions(mod)
    AddTrailingF64SqrtDropToDefinedFunctions =>
      metamorphic_add_trailing_f64_sqrt_drop_to_defined_functions(mod)
    AddLeadingF32CeilDropToDefinedFunctions =>
      metamorphic_add_leading_f32_ceil_drop_to_defined_functions(mod)
    AddTrailingF32CeilDropToDefinedFunctions =>
      metamorphic_add_trailing_f32_ceil_drop_to_defined_functions(mod)
    AddLeadingF32FloorDropToDefinedFunctions =>
      metamorphic_add_leading_f32_floor_drop_to_defined_functions(mod)
    AddTrailingF32FloorDropToDefinedFunctions =>
      metamorphic_add_trailing_f32_floor_drop_to_defined_functions(mod)
    AddLeadingF64CeilDropToDefinedFunctions =>
      metamorphic_add_leading_f64_ceil_drop_to_defined_functions(mod)
    AddTrailingF64CeilDropToDefinedFunctions =>
      metamorphic_add_trailing_f64_ceil_drop_to_defined_functions(mod)
    AddLeadingF64FloorDropToDefinedFunctions =>
      metamorphic_add_leading_f64_floor_drop_to_defined_functions(mod)
    AddTrailingF64FloorDropToDefinedFunctions =>
      metamorphic_add_trailing_f64_floor_drop_to_defined_functions(mod)
    AddLeadingF32TruncDropToDefinedFunctions =>
      metamorphic_add_leading_f32_trunc_drop_to_defined_functions(mod)
    AddTrailingF32TruncDropToDefinedFunctions =>
      metamorphic_add_trailing_f32_trunc_drop_to_defined_functions(mod)
    AddLeadingF32NearestDropToDefinedFunctions =>
      metamorphic_add_leading_f32_nearest_drop_to_defined_functions(mod)
    AddTrailingF32NearestDropToDefinedFunctions =>
      metamorphic_add_trailing_f32_nearest_drop_to_defined_functions(mod)
    AddLeadingF64TruncDropToDefinedFunctions =>
      metamorphic_add_leading_f64_trunc_drop_to_defined_functions(mod)
    AddTrailingF64TruncDropToDefinedFunctions =>
      metamorphic_add_trailing_f64_trunc_drop_to_defined_functions(mod)
    AddLeadingF64NearestDropToDefinedFunctions =>
      metamorphic_add_leading_f64_nearest_drop_to_defined_functions(mod)
    AddTrailingF64NearestDropToDefinedFunctions =>
      metamorphic_add_trailing_f64_nearest_drop_to_defined_functions(mod)
    AddLeadingF32AddDropToDefinedFunctions =>
      metamorphic_add_f32_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::f32_add(),
      )
    AddTrailingF32AddDropToDefinedFunctions =>
      metamorphic_add_f32_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::f32_add(),
      )
    AddLeadingF32SubDropToDefinedFunctions =>
      metamorphic_add_f32_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::f32_sub(),
      )
    AddTrailingF32SubDropToDefinedFunctions =>
      metamorphic_add_f32_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::f32_sub(),
      )
    AddLeadingF64AddDropToDefinedFunctions =>
      metamorphic_add_f64_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::f64_add(),
      )
    AddTrailingF64AddDropToDefinedFunctions =>
      metamorphic_add_f64_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::f64_add(),
      )
    AddLeadingF64SubDropToDefinedFunctions =>
      metamorphic_add_f64_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::f64_sub(),
      )
    AddTrailingF64SubDropToDefinedFunctions =>
      metamorphic_add_f64_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::f64_sub(),
      )
    AddLeadingF32MulDropToDefinedFunctions =>
      metamorphic_add_f32_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::f32_mul(),
      )
    AddTrailingF32MulDropToDefinedFunctions =>
      metamorphic_add_f32_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::f32_mul(),
      )
    AddLeadingF32DivDropToDefinedFunctions =>
      metamorphic_add_f32_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::f32_div(),
      )
    AddTrailingF32DivDropToDefinedFunctions =>
      metamorphic_add_f32_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::f32_div(),
      )
    AddLeadingF64MulDropToDefinedFunctions =>
      metamorphic_add_f64_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::f64_mul(),
      )
    AddTrailingF64MulDropToDefinedFunctions =>
      metamorphic_add_f64_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::f64_mul(),
      )
    AddLeadingF64DivDropToDefinedFunctions =>
      metamorphic_add_f64_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::f64_div(),
      )
    AddTrailingF64DivDropToDefinedFunctions =>
      metamorphic_add_f64_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::f64_div(),
      )
    AddLeadingF32MinDropToDefinedFunctions =>
      metamorphic_add_f32_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::f32_min(),
      )
    AddTrailingF32MinDropToDefinedFunctions =>
      metamorphic_add_f32_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::f32_min(),
      )
    AddLeadingF32MaxDropToDefinedFunctions =>
      metamorphic_add_f32_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::f32_max(),
      )
    AddTrailingF32MaxDropToDefinedFunctions =>
      metamorphic_add_f32_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::f32_max(),
      )
    AddLeadingF64MinDropToDefinedFunctions =>
      metamorphic_add_f64_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::f64_min(),
      )
    AddTrailingF64MinDropToDefinedFunctions =>
      metamorphic_add_f64_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::f64_min(),
      )
    AddLeadingF64MaxDropToDefinedFunctions =>
      metamorphic_add_f64_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::f64_max(),
      )
    AddTrailingF64MaxDropToDefinedFunctions =>
      metamorphic_add_f64_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::f64_max(),
      )
    AddLeadingF32CopysignDropToDefinedFunctions =>
      metamorphic_add_f32_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::f32_copysign(),
      )
    AddTrailingF32CopysignDropToDefinedFunctions =>
      metamorphic_add_f32_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::f32_copysign(),
      )
    AddLeadingF64CopysignDropToDefinedFunctions =>
      metamorphic_add_f64_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::f64_copysign(),
      )
    AddTrailingF64CopysignDropToDefinedFunctions =>
      metamorphic_add_f64_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::f64_copysign(),
      )
    AddLeadingF32EqDropToDefinedFunctions =>
      metamorphic_add_f32_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::f32_eq(),
      )
    AddTrailingF32EqDropToDefinedFunctions =>
      metamorphic_add_f32_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::f32_eq(),
      )
    AddLeadingF32NeDropToDefinedFunctions =>
      metamorphic_add_f32_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::f32_ne(),
      )
    AddTrailingF32NeDropToDefinedFunctions =>
      metamorphic_add_f32_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::f32_ne(),
      )
    AddLeadingF64EqDropToDefinedFunctions =>
      metamorphic_add_f64_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::f64_eq(),
      )
    AddTrailingF64EqDropToDefinedFunctions =>
      metamorphic_add_f64_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::f64_eq(),
      )
    AddLeadingF64NeDropToDefinedFunctions =>
      metamorphic_add_f64_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::f64_ne(),
      )
    AddTrailingF64NeDropToDefinedFunctions =>
      metamorphic_add_f64_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::f64_ne(),
      )
    AddLeadingF32LtDropToDefinedFunctions =>
      metamorphic_add_f32_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::f32_lt(),
      )
    AddTrailingF32LtDropToDefinedFunctions =>
      metamorphic_add_f32_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::f32_lt(),
      )
    AddLeadingF32GtDropToDefinedFunctions =>
      metamorphic_add_f32_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::f32_gt(),
      )
    AddTrailingF32GtDropToDefinedFunctions =>
      metamorphic_add_f32_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::f32_gt(),
      )
    AddLeadingF64LtDropToDefinedFunctions =>
      metamorphic_add_f64_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::f64_lt(),
      )
    AddTrailingF64LtDropToDefinedFunctions =>
      metamorphic_add_f64_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::f64_lt(),
      )
    AddLeadingF64GtDropToDefinedFunctions =>
      metamorphic_add_f64_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::f64_gt(),
      )
    AddTrailingF64GtDropToDefinedFunctions =>
      metamorphic_add_f64_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::f64_gt(),
      )
    AddLeadingF32LeDropToDefinedFunctions =>
      metamorphic_add_f32_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::f32_le(),
      )
    AddTrailingF32LeDropToDefinedFunctions =>
      metamorphic_add_f32_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::f32_le(),
      )
    AddLeadingF32GeDropToDefinedFunctions =>
      metamorphic_add_f32_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::f32_ge(),
      )
    AddTrailingF32GeDropToDefinedFunctions =>
      metamorphic_add_f32_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::f32_ge(),
      )
    AddLeadingF64LeDropToDefinedFunctions =>
      metamorphic_add_f64_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::f64_le(),
      )
    AddTrailingF64LeDropToDefinedFunctions =>
      metamorphic_add_f64_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::f64_le(),
      )
    AddLeadingF64GeDropToDefinedFunctions =>
      metamorphic_add_f64_binary_drop_to_defined_functions(
        mod,
        true,
        @lib.Instruction::f64_ge(),
      )
    AddTrailingF64GeDropToDefinedFunctions =>
      metamorphic_add_f64_binary_drop_to_defined_functions(
        mod,
        false,
        @lib.Instruction::f64_ge(),
      )
    AddLeadingNopToDefinedFunctions =>
      metamorphic_add_leading_nop_to_defined_functions(mod)
    AddTrailingNopToDefinedFunctions =>
      metamorphic_add_trailing_nop_to_defined_functions(mod)
    AddLeadingI32ConstDropToDefinedFunctions =>
      metamorphic_add_leading_i32_const_drop_to_defined_functions(mod)
    AddTrailingI32ConstDropToDefinedFunctions =>
      metamorphic_add_trailing_i32_const_drop_to_defined_functions(mod)
    AddTrailingEmptyVoidBlockToDefinedFunctions =>
      metamorphic_add_trailing_empty_void_block_to_defined_functions(mod)
    AddLeadingEmptyVoidBlockToDefinedFunctions =>
      metamorphic_add_leading_empty_void_block_to_defined_functions(mod)
    AddLeadingEmptyVoidLoopToDefinedFunctions =>
      metamorphic_add_leading_empty_void_loop_to_defined_functions(mod)
    AddTrailingEmptyVoidLoopToDefinedFunctions =>
      metamorphic_add_trailing_empty_void_loop_to_defined_functions(mod)
    WrapDefinedFunctionBodiesInIdentityBlock =>
      metamorphic_wrap_defined_function_bodies_in_identity_block(mod)
    SplitMergeLocalDeclarations =>
      metamorphic_split_merge_local_declarations(mod)
    AddExportAliases => metamorphic_add_export_aliases(mod)
    AddPrefixedExportAliases => metamorphic_add_prefixed_export_aliases(mod)
    AddSuffixedExportAliases => metamorphic_add_suffixed_export_aliases(mod)
    ReverseCustomSections => metamorphic_reverse_custom_sections(mod)
  }
  match validate_module(transformed) {
    Ok(_) =>
      Ok({
        transform_id: metamorphic_valid_transform_id(transform),
        wasm_module: transformed,
      })
    Err(err) =>
      Err(
        "metamorphic transform \{metamorphic_valid_transform_id(transform)} produced invalid module: \{validation_error_message(err)}",
      )
  }
}

///|
fn metamorphic_profile_config(
  profile : String,
) -> Result[GenValidConfig, String] {
  match profile {
    "smoke" | "ci" | "stress" => Ok(GenValidConfig::natural_default())
    _ => Err("unknown validate-valid-metamorphic profile: \{profile}")
  }
}

///|
fn metamorphic_profile_case_count(profile : String) -> Result[Int, String] {
  match profile {
    "smoke" => Ok(1)
    "ci" => Ok(10)
    "stress" => Ok(100)
    _ => Err("unknown validate-valid-metamorphic profile: \{profile}")
  }
}

///|
pub fn run_validate_valid_metamorphic_fuzz(
  profile : String,
  seed : UInt64,
) -> Result[ValidateValidMetamorphicFuzzStats, String] {
  let config = match metamorphic_profile_config(profile) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let case_count = match metamorphic_profile_case_count(profile) {
    Ok(v) => v
    Err(msg) => return Err(msg)
  }
  let transforms = metamorphic_valid_transforms()
  let transform_ids = transforms.map(metamorphic_valid_transform_id)
  let mut attempts = 0
  let mut generated_count = 0
  let mut transformed_count = 0
  let mut validated_count = 0
  let mut i = 0
  while i < case_count {
    let generated = match
      gen_valid_module_result_from_seed(seed ^ i.to_uint64(), config) {
      Ok(v) => v
      Err(e) =>
        return Err("GenValid source failed: \{e.validation_error_message}")
    }
    attempts += generated.attempts
    generated_count += 1
    for transform in transforms {
      match metamorphic_apply_transform(generated.wasm_module, transform) {
        Ok(_) => {
          transformed_count += 1
          validated_count += 1
        }
        Err(msg) => return Err(msg)
      }
    }
    i += 1
  }
  Ok({
    profile,
    attempts,
    generated: generated_count,
    transformed: transformed_count,
    validated: validated_count,
    transform_ids,
  })
}
