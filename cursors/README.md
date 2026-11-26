# Cursor

`Bibata-Modern-Ice.tar.gz` is [Bibata Cursor](https://github.com/ful1e5/Bibata_Cursor)
by Abdulkaiz Khatri, Modern Ice variant (white, rounded), unchanged. It's
licensed under the GNU GPL v3; the full text is in [`LICENSE`](LICENSE).

`install.sh` unpacks it into `~/.local/share/icons`. By hand:

```sh
mkdir -p ~/.local/share/icons
tar -xzf Bibata-Modern-Ice.tar.gz -C ~/.local/share/icons
```

then add `cursor = "Bibata-Modern-Ice"` to your `quartz.setup({ … })`.
