Get-ChildItem 'C:\Users\hites\Downloads\Az.RBACPermissions\Az.RBACPermissions\AADGroups' | ForEach-Object {
  & $_.FullName
}