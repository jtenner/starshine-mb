declare const opaqueBrand: unique symbol;
export type OpaqueHandle<Name extends string> = { readonly [opaqueBrand]: Name };

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
