// Test-only libc fault injection around the unchanged production C bridge.
#include <errno.h>
#include <stdio.h>
#include <string.h>

static FILE *owned;
static int fault, opens, closes;
static FILE *injected_fopen(const char *, const char *);
static int injected_fseek(FILE *, long, int);
static long injected_ftell(FILE *);
static size_t injected_fread(void *, size_t, size_t, FILE *);
static size_t injected_fwrite(const void *, size_t, size_t, FILE *);
static int injected_fflush(FILE *);
static int injected_fclose(FILE *);

#define fopen injected_fopen
#define fseek injected_fseek
#define ftell injected_ftell
#define fread injected_fread
#define fwrite injected_fwrite
#define fflush injected_fflush
#define fclose injected_fclose
#include "fs_native.inc"
#undef fopen
#undef fseek
#undef ftell
#undef fread
#undef fwrite
#undef fflush
#undef fclose

static FILE *injected_fopen(const char *path, const char *mode) {
  if (strcmp(path, "resource-lifetime-fixture") != 0) return fopen(path, mode);
  if (fault == 1) { errno = EACCES; return NULL; }
  owned = tmpfile();
  if (!owned) return NULL;
  if (mode[0] == 'r') {
    fwrite("wasm", 1, 4, owned);
    rewind(owned);
  }
  opens++;
  return owned;
}

static int injected_fseek(FILE *stream, long offset, int whence) {
  if (stream == owned && ((fault == 2 && whence == SEEK_END) ||
                          (fault == 4 && whence == SEEK_SET))) {
    errno = EIO; return -1;
  }
  return fseek(stream, offset, whence);
}

static long injected_ftell(FILE *stream) {
  if (stream == owned && fault == 3) { errno = EIO; return -1; }
  return ftell(stream);
}

static size_t injected_fread(void *ptr, size_t size, size_t count, FILE *stream) {
  if (stream == owned && fault == 5) { errno = EIO; return count - 1; }
  return fread(ptr, size, count, stream);
}

static size_t injected_fwrite(const void *ptr, size_t size, size_t count, FILE *stream) {
  if (stream == owned && fault == 6) { errno = EIO; return count - 1; }
  return fwrite(ptr, size, count, stream);
}

static int injected_fflush(FILE *stream) {
  if (stream == owned && fault == 7) { errno = EIO; return EOF; }
  return fflush(stream);
}

static int injected_fclose(FILE *stream) {
  if (stream != owned) return fclose(stream);
  closes++;
  owned = NULL;
  int result = fclose(stream);
  // Cleanup must not replace the original I/O error with this errno.
  errno = EBADF;
  return fault == 8 ? EOF : result;
}

MOONBIT_FFI_EXPORT void lifetime_configure(int stage) {
  if (owned) fclose(owned); // Release a failed test's stream before the next case.
  owned = NULL;
  fault = stage;
  opens = closes = 0;
}
MOONBIT_FFI_EXPORT int lifetime_live(void) { return owned != NULL; }
MOONBIT_FFI_EXPORT int lifetime_opens(void) { return opens; }
MOONBIT_FFI_EXPORT int lifetime_closes(void) { return closes; }
MOONBIT_FFI_EXPORT moonbit_bytes_t lifetime_message(int kind) {
  const char *message = strerror(kind == 1 ? EACCES : kind == 8 ? EBADF : EIO);
  moonbit_bytes_t result = moonbit_make_bytes(strlen(message), 0);
  memcpy(result, message, strlen(message));
  return result;
}
