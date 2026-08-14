# Pub packaging notes for FrameGuard
#
# Required for a strong pub.dev score:
# - Valid pubspec (description, homepage, repository, topics, screenshots)
# - LICENSE (MIT)
# - CHANGELOG.md
# - README.md with usage examples
# - dartdoc-friendly public API (/// comments)
# - Passing analyzer + tests
#
# Before first publish:
# 1. Create the GitHub repo (or update homepage/repository URLs)
# 2. Verify publisher on pub.dev
# 3. flutter pub publish --dry-run
# 4. flutter pub publish
#
# Do not publish secrets. Reports/baselines under local folders are .pubignored.
