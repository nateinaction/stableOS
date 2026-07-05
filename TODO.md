Which items remain guidelines, which remain ADRs.
Every guideline should have at least one related ADR.
Guidelines should not mention solutions or specific applications.
- [ ] Separate out 1Password decision from 004 software tiers, need password manager ADR since password managers have become OS standard
- [ ] Separate ADR on terminal emulator choice: warp vs alacrity, warp chosen for rust, next command prediction
- [ ] Separate ADR on chezmoi
- [ ] Separate ADR on fzf
- [ ] Separate ADR on zoxide: other options rupa/z, a fish native z, oh-my-fish z integration
- [ ] ADR on handling statefull information in home dir? Backup solution?
- [ ] ADR on tailscale choice?

Add system-wide utilities must be accompanied by an ADR.

Should ADRs be permanent cluttering up the ADR dir or should we use git history instead?
