package main

import (
	"bytes"
	"encoding/binary"
	"os"
	"path/filepath"
	"testing"
)

func TestBulkBinaryRoundTrip(t *testing.T) {
	dir := t.TempDir()
	name := filepath.Join(dir, "λ.wasm")
	data := bytes.Repeat([]byte{0, 255, 1, 128}, 256*1024)
	packet := make([]byte, 4+len(name)+len(data))
	binary.LittleEndian.PutUint32(packet, uint32(len(name)))
	copy(packet[4:], name)
	copy(packet[4+len(name):], data)
	h := &bulkHost{}
	if _, status, err := h.execute(5, packet); err != nil || status != 0 {
		t.Fatalf("write: %d, %v", status, err)
	}
	got, status, err := h.execute(4, []byte(name))
	if err != nil || status != 0 || !bytes.Equal(got, data) {
		t.Fatalf("read: %d, %v, equal=%v", status, err, bytes.Equal(got, data))
	}
	if _, _, err := h.execute(5, []byte{0, 0, 0}); err == nil {
		t.Fatal("accepted truncated header")
	}
	if _, _, err := h.execute(5, []byte{255, 255, 255, 255}); err == nil {
		t.Fatal("accepted truncated path")
	}
	if _, _, err := h.execute(4, []byte{255}); err == nil {
		t.Fatal("accepted invalid UTF-8")
	}
	if _, _, err := h.execute(4, []byte(filepath.Join(dir, "missing"))); err == nil {
		t.Fatal("missing input read succeeded")
	}
	if _, _, err := h.execute(999, nil); err == nil {
		t.Fatal("unknown operation succeeded")
	}
}
func TestBulkArgumentsAndEnvironment(t *testing.T) {
	h := &bulkHost{args: []string{"λ.wasm", "-O4z"}}
	got, status, err := h.execute(1, nil)
	if err != nil || status != 0 || string(got) != `["λ.wasm","-O4z"]` {
		t.Fatalf("args: %s, %d, %v", got, status, err)
	}
	const name = "STARSHINE_BULK_HOST_TEST_ENV"
	old, present := os.LookupEnv(name)
	os.Unsetenv(name)
	t.Cleanup(func() {
		if present {
			os.Setenv(name, old)
		} else {
			os.Unsetenv(name)
		}
	})
	if got, status, err := h.execute(2, []byte(name)); err != nil || status != 2 || len(got) != 0 {
		t.Fatalf("missing env: %q, %d, %v", got, status, err)
	}
	t.Setenv(name, "")
	if got, status, err := h.execute(2, []byte(name)); err != nil || status != 0 || len(got) != 0 {
		t.Fatalf("empty env: %q, %d, %v", got, status, err)
	}
}
