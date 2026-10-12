package main

import (
	"context"
	"encoding/binary"
	"encoding/json"
	"fmt"
	w "github.com/wago-org/wago"
	"os"
	"path/filepath"
	"runtime"
	"sort"
	"time"
	"unicode/utf8"
)

type bulkHost struct {
	args                []string
	pending             []byte
	requests, responses int
	operations          map[int32]int
}

func text(b []byte) (string, error) {
	if !utf8.Valid(b) {
		return "", fmt.Errorf("invalid UTF-8 in bulk CLI request")
	}
	return string(b), nil
}
func (h *bulkHost) execute(op int32, b []byte) ([]byte, byte, error) {
	switch op {
	case 1:
		out, err := json.Marshal(h.args)
		return out, 0, err
	case 2:
		name, err := text(b)
		if err != nil {
			return nil, 0, err
		}
		value, ok := os.LookupEnv(name)
		if !ok {
			return nil, 2, nil
		}
		return []byte(value), 0, nil
	case 3:
		name, err := text(b)
		if err != nil {
			return nil, 0, err
		}
		info, err := os.Stat(name)
		if os.IsNotExist(err) {
			return []byte{0}, 0, nil
		}
		if err != nil {
			return nil, 0, err
		}
		if info.Mode().IsRegular() {
			return []byte{1}, 0, nil
		}
		return []byte{0}, 0, nil
	case 4:
		name, err := text(b)
		if err != nil {
			return nil, 0, err
		}
		out, err := os.ReadFile(name)
		return out, 0, err
	case 5:
		if len(b) < 4 {
			return nil, 0, fmt.Errorf("truncated bulk CLI write packet")
		}
		n := uint64(binary.LittleEndian.Uint32(b))
		if n > uint64(len(b)-4) {
			return nil, 0, fmt.Errorf("truncated bulk CLI write path")
		}
		name, err := text(b[4 : 4+n])
		if err != nil {
			return nil, 0, err
		}
		return nil, 0, os.WriteFile(name, b[4+n:], 0644)
	case 6:
		names := []string{}
		err := filepath.WalkDir(".", func(name string, d os.DirEntry, err error) error {
			if err != nil {
				return err
			}
			if d.Type().IsRegular() {
				names = append(names, filepath.ToSlash(name))
			}
			return nil
		})
		if err != nil {
			return nil, 0, err
		}
		sort.Strings(names)
		out, err := json.Marshal(names)
		return out, 0, err
	case 7:
		_, err := os.Stdout.Write(b)
		return nil, 0, err
	case 8:
		_, err := os.Stderr.Write(b)
		return nil, 0, err
	default:
		return nil, 0, fmt.Errorf("unknown bulk CLI operation %d", op)
	}
}
func (h *bulkHost) request(c w.Caller, k w.HostCall) {
	h.requests++
	if h.pending != nil {
		panic("bulk CLI response is still pending")
	}
	op := k.I32(0)
	h.operations[op]++
	err := c.WithGuestStorage(func(s w.GuestStorage) error {
		b, err := s.MemoryRange(0, uint64(uint32(k.I32(1))), uint64(uint32(k.I32(2))), w.GuestStorageRead)
		if err != nil {
			return err
		}
		payload, status, err := h.execute(op, b)
		if err != nil {
			status = 1
			payload = []byte(err.Error())
		}
		if len(payload) >= 0x7fffffff {
			return fmt.Errorf("bulk CLI response is too large")
		}
		h.pending = make([]byte, len(payload)+1)
		h.pending[0] = status
		copy(h.pending[1:], payload)
		return nil
	})
	if err != nil {
		panic(err)
	}
	k.SetI32(0, int32(len(h.pending)))
}
func (h *bulkHost) response(c w.Caller, k w.HostCall) {
	h.responses++
	if h.pending == nil {
		panic("bulk CLI has no pending response")
	}
	capacity := k.I32(1)
	if capacity < 0 || int(capacity) < len(h.pending) {
		panic("bulk CLI response capacity is too small")
	}
	err := c.WithGuestStorage(func(s w.GuestStorage) error {
		b, err := s.MemoryRange(0, uint64(uint32(k.I32(0))), uint64(len(h.pending)), w.GuestStorageWrite)
		if err != nil {
			return err
		}
		copy(b, h.pending)
		return nil
	})
	if err != nil {
		panic(err)
	}
	k.SetI32(0, int32(len(h.pending)))
	h.pending = nil
}

// The compiler retains unused optional CmdIO closures. These imports must not
// execute through the bulk entry point. Bind them only to explicit traps.
func legacyTraps(im *w.Imports) {
	x, i := w.ValExternRef, w.ValI32
	register := func(names []string, p, r []w.ValType) {
		for _, name := range names {
			n := name
			im.HostFunc("__moonbit_fs_unstable", n, func(w.HostCall) { panic("unexpected legacy filesystem call: " + n) }).Params(p...).Results(r...)
		}
	}
	register([]string{"args_get", "get_error_message", "get_file_content", "get_dir_files", "begin_create_string", "begin_create_byte_array", "current_dir"}, nil, []w.ValType{x})
	register([]string{"begin_read_string", "finish_create_string", "begin_read_byte_array", "finish_create_byte_array", "begin_read_string_array", "string_array_read_string"}, []w.ValType{x}, []w.ValType{x})
	register([]string{"string_read_char", "byte_array_read_byte", "read_file_to_bytes_new", "is_file_new", "is_dir_new", "path_exists", "read_dir_new", "create_dir_new", "remove_file_new", "remove_dir_new"}, []w.ValType{x}, []w.ValType{i})
	register([]string{"finish_read_string", "finish_read_byte_array", "finish_read_string_array"}, []w.ValType{x}, nil)
	register([]string{"string_append_char", "byte_array_append_byte"}, []w.ValType{x, i}, nil)
	register([]string{"write_bytes_to_file_new"}, []w.ValType{x, x}, []w.ValType{i})
}

func run() (code int) {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: starshine-wago <cmd_gc.wasm> [Starshine arguments]")
		return 2
	}
	h := &bulkHost{args: os.Args[2:], operations: map[int32]int{}}
	report := map[string]any{}
	started := time.Now()
	var before, after runtime.MemStats
	runtime.ReadMemStats(&before)
	defer func() {
		runtime.ReadMemStats(&after)
		report["wall_ms"] = float64(time.Since(started).Microseconds()) / 1000
		report["requests"], report["responses"], report["operations"] = h.requests, h.responses, h.operations
		report["go_total_alloc_bytes"] = after.TotalAlloc - before.TotalAlloc
		report["go_malloc_count"] = after.Mallocs - before.Mallocs
		report["go_gc_cycles"] = after.NumGC - before.NumGC
		report["exit_code"] = code
		if name := os.Getenv("STARSHINE_BENCH_REPORT"); name != "" {
			b, err := json.MarshalIndent(report, "", "  ")
			if err == nil {
				err = os.WriteFile(name, append(b, '\n'), 0644)
			}
			if err != nil {
				fmt.Fprintln(os.Stderr, err)
				code = 1
			}
		}
	}()
	cfg := w.NewRuntimeConfig().WithCoreFeatures(w.CoreFeaturesV3).WithBoundsChecks(w.BoundsChecksExplicit).WithNativeStackBytes(64 << 20)
	rt := w.NewRuntime(w.WithRuntimeConfig(cfg))
	defer rt.Close()
	bytes, err := os.ReadFile(os.Args[1])
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 1
	}
	t := time.Now()
	mod, err := rt.Compile(bytes)
	report["compile_ms"] = float64(time.Since(t).Microseconds()) / 1000
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 1
	}
	report["gc_root_admission"] = mod.Compiled().GCNativeRootAdmission()
	im := w.NewImports()
	legacyTraps(im)
	im.HostFunc("__starshine_cli_v1", "request", h.request).Params(w.ValI32, w.ValI32, w.ValI32).Results(w.ValI32)
	im.HostFunc("__starshine_cli_v1", "response", h.response).Params(w.ValI32, w.ValI32).Results(w.ValI32)
	im.HostFunc("__starshine_cli_v1", "exit", func(k w.HostCall) { code = int(k.I32(0)); panic("Starshine command failed") }).Params(w.ValI32)
	im.HostFunc("__moonbit_time_unstable", "now", func(k w.HostCall) { k.SetI64(0, time.Now().UnixMilli()) }).Results(w.ValI64)
	t = time.Now()
	in, err := rt.Instantiate(context.Background(), mod, w.WithImports(im), w.WithGC(w.GCConfig{ThroughputHeapBytes: 2 << 30, NurseryBytes: 64 << 20}))
	report["instantiate_ms"] = float64(time.Since(t).Microseconds()) / 1000
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 1
	}
	defer in.Close()
	t = time.Now()
	_, err = in.Invoke("_start")
	report["invoke_ms"] = float64(time.Since(t).Microseconds()) / 1000
	if err != nil {
		report["error"] = err.Error()
		fmt.Fprintln(os.Stderr, err)
		if code == 0 {
			code = 1
		}
	}
	return code
}
func main() { os.Exit(run()) }
