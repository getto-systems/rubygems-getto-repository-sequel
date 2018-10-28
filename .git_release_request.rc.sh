git_release_request_dump_version_local(){
  bundle
  git add Gemfile.lock
}
git_release_request_after_tag(){
  git push github master --tags
}
