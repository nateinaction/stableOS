package tests

import (
	"os"
	"os/exec"
	"strings"
	"testing"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

func TestImage(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "stableOS Image Suite")
}

func runInImage(args ...string) (string, error) {
	img := os.Getenv("IMG")
	if img == "" {
		img = "localhost/stableos:test"
	}

	cmd := append([]string{"run", "--rm", img}, args...)
	out, err := exec.Command("podman", cmd...).CombinedOutput()
	return strings.TrimSpace(string(out)), err
}

var _ = Describe("stableOS image", func() {
	Describe("packages", func() {
		It("has tailscale installed", func() {
			_, err := runInImage("command", "-v", "tailscale")
			Expect(err).NotTo(HaveOccurred())
		})

		It("has fish installed", func() {
			_, err := runInImage("command", "-v", "fish")
			Expect(err).NotTo(HaveOccurred())
		})

		It("has chezmoi installed", func() {
			_, err := runInImage("command", "-v", "chezmoi")
			Expect(err).NotTo(HaveOccurred())
		})
	})

	Describe("/opt redirect", func() {
		It("redirects /opt to /usr/lib/opt", func() {
			out, err := runInImage("readlink", "/opt")
			Expect(err).NotTo(HaveOccurred())
			Expect(out).To(Equal("/usr/lib/opt"))
		})
	})

	Describe("shell configuration", func() {
		It("registers fish in /etc/shells", func() {
			_, err := runInImage("grep", "-qx", "/usr/bin/fish", "/etc/shells")
			Expect(err).NotTo(HaveOccurred())
		})
	})

	Describe("systemd services", func() {
		It("enables tailscaled.service", func() {
			out, err := runInImage("systemctl", "is-enabled", "tailscaled.service")
			Expect(err).NotTo(HaveOccurred())
			Expect(strings.TrimSpace(out)).To(Equal("enabled"))
		})

		It("enables bootc-fetch-apply-updates.timer", func() {
			out, err := runInImage("systemctl", "is-enabled", "bootc-fetch-apply-updates.timer")
			Expect(err).NotTo(HaveOccurred())
			Expect(strings.TrimSpace(out)).To(Equal("enabled"))
		})

		It("enables flathub-setup.service", func() {
			out, err := runInImage("systemctl", "is-enabled", "flathub-setup.service")
			Expect(err).NotTo(HaveOccurred())
			Expect(strings.TrimSpace(out)).To(Equal("enabled"))
		})
	})

	Describe("skeleton and systemd files", func() {
		It("ships COSMIC skeleton config", func() {
			_, err := runInImage("test", "-f", "/etc/skel/.config/cosmic/shell.ron")
			Expect(err).NotTo(HaveOccurred())
		})

		It("ships fish skeleton config", func() {
			_, err := runInImage("test", "-f", "/etc/skel/.config/fish/config.fish")
			Expect(err).NotTo(HaveOccurred())
		})

		It("ships flathub-setup.service unit", func() {
			_, err := runInImage("test", "-f", "/usr/lib/systemd/system/flathub-setup.service")
			Expect(err).NotTo(HaveOccurred())
		})
	})
})
