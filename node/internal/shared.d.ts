export type OpaqueHandle<Name extends string> = {
  readonly __starshineBrand: Name;
};

export type StarshineResult<T, E> =
  | {
      ok: true;
      value: T;
    }
  | {
      ok: false;
      error: E;
      display?: string;
    };
