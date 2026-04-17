# Clean screenshots & screen recordings from Desktop
clean-desktop() {
  local count=0
  local file

  for file in ~/Desktop/Screenshot*.png(N) ~/Desktop/Screen\ Recording*.mov(N); do
    [[ -f "$file" ]] || continue
    rm "$file"
    echo "Deleted: ${file:t}"
    ((count++))
  done

  if (( count == 0 )); then
    echo "Desktop is already clean."
  else
    echo "\nRemoved $count file(s)."
  fi
}
alias cldr="clean-desktop"
