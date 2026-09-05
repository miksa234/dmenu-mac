/* See LICENSE for copyright and license details. */
#include <dirent.h>
#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#define CACHE ".cache/dmenu_mac_cache"

static char **items;
static const char *home, *path;

static void die(const char *message) {
  fprintf(stderr, "dmenu-mac_path: %s\n", message);
  exit(EXIT_FAILURE);
}

static void make_cache_dir(void) {
  if (mkdir(".cache", 0700) < 0 && errno != EEXIST)
    die("mkdir .cache failed");
  if (mkdir(".cache/dmenu", 0700) < 0 && errno != EEXIST)
    die("mkdir .cache/dmenu failed");
}

static int qstrcmp(const void *a, const void *b) {
  return strcmp(*(const char **)a, *(const char **)b);
}

static int uptodate(void) {
  char *copy, *directory;
  struct stat status;
  if (stat(CACHE, &status) < 0)
    return 0;
  time_t modified = status.st_mtime;
  FILE *cache = fopen(CACHE, "r");
  char *cached_path = NULL;
  size_t size = 0;
  ssize_t length = cache ? getline(&cached_path, &size, cache) : -1;
  if (cache)
    fclose(cache);
  if (length < 2 || cached_path[length - 1] != '\n') {
    free(cached_path);
    return 0;
  }
  cached_path[length - 1] = '\0';
  int same_path = !strcmp(cached_path, path);
  free(cached_path);
  if (!same_path)
    return 0;
  if (!(copy = strdup(path)))
    die("strdup failed");
  for (directory = strtok(copy, ":"); directory;
       directory = strtok(NULL, ":")) {
    if (!stat(directory, &status) && status.st_mtime > modified) {
      free(copy);
      return 0;
    }
  }
  free(copy);
  return 1;
}

static void print_cache(void) {
  char buffer[BUFSIZ];
  FILE *cache = fopen(CACHE, "r");
  if (!cache)
    die("open cache failed");
  char *cached_path = NULL;
  size_t size = 0;
  if (getline(&cached_path, &size, cache) < 0)
    die("read cache failed");
  free(cached_path);
  while (fgets(buffer, sizeof buffer, cache))
    fputs(buffer, stdout);
  if (ferror(cache))
    die("read cache failed");
  fclose(cache);
}

static void scan(void) {
  char buffer[PATH_MAX];
  char *copy, *directory;
  size_t count = 0;
  if (!(copy = strdup(path)))
    die("strdup failed");
  for (directory = strtok(copy, ":"); directory;
       directory = strtok(NULL, ":")) {
    DIR *dir = opendir(directory);
    if (!dir)
      continue;
    struct dirent *entry;
    while ((entry = readdir(dir))) {
      struct stat status;
      if (entry->d_name[0] == '.')
        continue;
      if (snprintf(buffer, sizeof buffer, "%s/%s", directory, entry->d_name) >=
              (int)sizeof buffer ||
          stat(buffer, &status) < 0 || !S_ISREG(status.st_mode) ||
          access(buffer, X_OK) < 0)
        continue;
      char **grown = realloc(items, (count + 1) * sizeof *items);
      if (!grown)
        die("realloc failed");
      items = grown;
      if (!(items[count++] = strdup(entry->d_name)))
        die("strdup failed");
    }
    closedir(dir);
  }
  free(copy);
  qsort(items, count, sizeof *items, qstrcmp);
  FILE *cache = fopen(CACHE, "w");
  if (!cache)
    die("open cache failed");
  fprintf(cache, "%s\n", path);
  for (size_t i = 0; i < count; i++) {
    if (i && !strcmp(items[i], items[i - 1]))
      continue;
    fprintf(cache, "%s\n", items[i]);
    printf("%s\n", items[i]);
  }
  if (fclose(cache) == EOF)
    die("write cache failed");
}

int main(void) {
  if (!(home = getenv("HOME")))
    die("no $HOME");
  if (!(path = getenv("PATH")))
    die("no $PATH");
  if (chdir(home) < 0)
    die("chdir failed");
  make_cache_dir();
  if (uptodate())
    print_cache();
  else
    scan();
  return EXIT_SUCCESS;
}
