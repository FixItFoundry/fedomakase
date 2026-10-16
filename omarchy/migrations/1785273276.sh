echo "Drop Kvantum now that Qt apps follow the theme through the GTK platform theme"

targets=()
for pkg in kvantum-qt5 kvantum; do
  omarchy-pkg-present "$pkg" && targets+=("$pkg")
done

if ((${#targets[@]})); then
  omarchy-pkg-drop "${targets[@]}" ||
    echo "Could not remove Kvantum; leaving it installed." >&2
fi
