/*
Copyright 2025 The OADP CLI Contributors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package tests

import (
	"bytes"
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
	"time"
)

const (
	binaryName   = "oadp-test"
	buildTimeout = 30 * time.Second
	testTimeout  = 10 * time.Second
)

// buildCLIBinary builds the CLI binary for testing
// NOTE: This builds from LOCAL code (current filesystem), not repository code
func buildCLIBinary(t *testing.T) string {
	t.Helper()

	// Create temporary directory for the binary
	tmpDir := t.TempDir()

	// Add .exe extension on Windows
	binaryNameWithExt := binaryName
	if runtime.GOOS == "windows" {
		binaryNameWithExt += ".exe"
	}
	binaryPath := filepath.Join(tmpDir, binaryNameWithExt)

	// Build the binary from parent directory (project root)
	// This uses whatever code is currently on disk (including uncommitted changes)
	ctx, cancel := context.WithTimeout(context.Background(), buildTimeout)
	defer cancel()

	projectRoot := getProjectRoot(t)
	cmd := exec.CommandContext(ctx, "go", "build", "-o", binaryPath, ".")
	cmd.Dir = projectRoot

	var stderr bytes.Buffer
	cmd.Stderr = &stderr

	t.Logf("Building CLI binary: %s", binaryPath)
	t.Logf("Project root: %s", projectRoot)

	if err := cmd.Run(); err != nil {
		t.Fatalf("Failed to build CLI binary: %v\nStderr: %s", err, stderr.String())
	}

	// Verify the binary was created
	if _, err := os.Stat(binaryPath); err != nil {
		t.Fatalf("Binary not found after build: %v", err)
	}

	return binaryPath
}

// getProjectRoot returns the project root directory
func getProjectRoot(t *testing.T) string {
	t.Helper()

	// Start from the current directory (tests folder)
	dir, err := os.Getwd()
	if err != nil {
		t.Fatalf("Failed to get working directory: %v", err)
	}

	// Look for go.mod in current dir and parent directories
	for {
		goModPath := filepath.Join(dir, "go.mod")
		if _, err := os.Stat(goModPath); err == nil {
			// Check if this is the main project go.mod (not the tests go.mod)
			if filepath.Base(dir) != "tests" {
				return dir
			}
		}

		parent := filepath.Dir(dir)
		if parent == dir {
			break
		}
		dir = parent
	}

	t.Fatalf("Could not find project root (go.mod not found)")
	return ""
}

// testHelpCommand tests a help command and verifies expected content
func testHelpCommand(t *testing.T, binaryPath string, args []string, expectContains []string) {
	t.Helper()

	ctx, cancel := context.WithTimeout(context.Background(), testTimeout)
	defer cancel()

	cmd := exec.CommandContext(ctx, binaryPath, args...)

	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	err := cmd.Run()
	output := stdout.String()

	// Help commands typically exit with 0
	if err != nil {
		t.Logf("Command failed (this might be expected for some help commands): %v", err)
		t.Logf("Stderr: %s", stderr.String())
		// For help commands, we often get the help text in stderr too
		if stderr.Len() > 0 {
			output += stderr.String()
		}
	}

	t.Logf("Command: %s %s", binaryPath, strings.Join(args, " "))
	t.Logf("Output:\n%s", output)

	// Check that expected content is present
	for _, expected := range expectContains {
		if !strings.Contains(output, expected) {
			t.Errorf("Expected output to contain %q, but it didn't.\nFull output:\n%s", expected, output)
		}
	}

	// Basic sanity check - help output should not be empty
	if len(strings.TrimSpace(output)) == 0 {
		t.Error("Help output was empty")
	}
}

// cleanup removes test artifacts
func cleanup(t *testing.T, binaryPath string) {
	t.Helper()
	if err := os.Remove(binaryPath); err != nil && !os.IsNotExist(err) {
		t.Logf("Warning: Failed to cleanup binary %s: %v", binaryPath, err)
	}
}
