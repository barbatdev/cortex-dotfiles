package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestDoctorHealthyHostPasses(t *testing.T) {
	s := newSandbox(t)
	s.healthy()
	if err := cmdDoctor(s.env); err != nil {
		t.Fatalf("healthy host must pass: %v\n%s", err, s.out.String())
	}
	contains(t, s.out.String(), "ok   engram")
	contains(t, s.out.String(), "ok   engram instance-id")
	notContains(t, s.out.String(), "FAIL")
}

func TestDoctorFailsOnSymlinkedEngram(t *testing.T) {
	s := newSandbox(t)
	s.healthy()
	real := filepath.Join(s.home, "elsewhere", "engram")
	s.script(real, engramBody("3.6.2", false))
	os.Remove(s.env.Target("engram"))
	if err := os.Symlink(real, s.env.Target("engram")); err != nil {
		t.Fatal(err)
	}
	if cmdDoctor(s.env) == nil {
		t.Fatal("symlinked engram must fail doctor")
	}
	contains(t, s.out.String(), "FAIL engram")
	contains(t, s.out.String(), "is a symlink")
}

func TestDoctorFailsOnPreV3Engram(t *testing.T) {
	s := newSandbox(t)
	s.healthy()
	s.script(s.env.Target("engram"), engramBody("1.20.1", true))
	if cmdDoctor(s.env) == nil {
		t.Fatal("pre-v3 engram must fail doctor")
	}
	contains(t, s.out.String(), "FAIL engram instance-id")
}

func TestDoctorFailsWhenGhIsNotAuthenticated(t *testing.T) {
	s := newSandbox(t)
	s.healthy()
	s.stub("gh", `exit 1`)
	if cmdDoctor(s.env) == nil {
		t.Fatal("unauthenticated gh must fail doctor")
	}
	contains(t, s.out.String(), "FAIL gh auth")
}

func TestDoctorWarnsOnStrayCopiesAndGOBIN(t *testing.T) {
	s := newSandbox(t)
	s.healthy()
	s.script(filepath.Join(s.home, "go", "bin", "engram"), engramBody("1.20.1", true))
	s.script(s.env.Target("gentle-ai")+".pre-gw", aiBody("1"))
	t.Setenv("GOBIN", s.env.BinDir())
	if err := cmdDoctor(s.env); err != nil {
		t.Fatalf("warnings alone must not fail doctor: %v\n%s", err, s.out.String())
	}
	contains(t, s.out.String(), "WARN stray copy "+filepath.Join(s.home, "go", "bin", "engram"))
	contains(t, s.out.String(), "WARN stray copy "+s.env.Target("gentle-ai")+".pre-gw")
	contains(t, s.out.String(), "WARN go env GOBIN")
}

func TestDoctorFailsWhenPathResolvesAnotherCopy(t *testing.T) {
	s := newSandbox(t)
	s.healthy()
	s.stub("engram", engramBody("1.20.1", true))
	if cmdDoctor(s.env) == nil {
		t.Fatal("engram resolving outside ~/.local/bin must fail")
	}
	contains(t, s.out.String(), "FAIL engram on PATH")
}
