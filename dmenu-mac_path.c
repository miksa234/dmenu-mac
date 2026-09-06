/* See LICENSE for copyright and license details. */
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <fts.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

#define CACHE ".cache/dmenu_mac_cache"
#define CACHE_TTL 30

static char **items;
static const char *home, *path;
static char working_directory[PATH_MAX];

static void
die (const char *message)
{
    fprintf (stderr, "dmenu-mac_path: %s\n", message);
    exit (EXIT_FAILURE);
}

static void
make_cache_dir (void)
{
    if (mkdir (".cache", 0700) < 0 && errno != EEXIST)
        die ("mkdir .cache failed");
}

static int
qstrcmp (const void *a, const void *b)
{
    return strcmp (*(const char **)a, *(const char **)b);
}

static const char *
next_path_directory (const char **cursor, char *buffer, size_t size)
{
    if (!*cursor)
        return NULL;
    const char *start = *cursor;
    const char *end = strchr (start, ':');
    size_t length = end ? (size_t)(end - start) : strlen (start);
    *cursor = end ? end + 1 : NULL;
    if (!length)
        return working_directory;
    if (length >= size)
        die ("PATH component too long");
    memcpy (buffer, start, length);
    buffer[length] = '\0';
    return buffer;
}

static int
uptodate (void)
{
    char directory_buffer[PATH_MAX];
    const char *cursor = path, *directory;
    struct stat status;
    if (stat (CACHE, &status) < 0)
        return 0;
    if (time (NULL) - status.st_mtime >= CACHE_TTL)
        return 0;
    time_t modified = status.st_mtime;
    FILE *cache = fopen (CACHE, "r");
    char *cached_path = NULL;
    size_t size = 0;
    ssize_t length = cache ? getline (&cached_path, &size, cache) : -1;
    if (cache)
        fclose (cache);
    if (length < 2 || cached_path[length - 1] != '\n') {
        free (cached_path);
        return 0;
    }
    cached_path[length - 1] = '\0';
    int same_path = !strcmp (cached_path, path);
    free (cached_path);
    if (!same_path)
        return 0;
    while ((directory = next_path_directory (
                &cursor, directory_buffer, sizeof directory_buffer))) {
        if (!stat (directory, &status) && status.st_mtime > modified)
            return 0;
    }
    return 1;
}

static void
add_item (const char *item, size_t *count)
{
    char **grown = realloc (items, (*count + 1) * sizeof *items);
    if (!grown)
        die ("realloc failed");
    items = grown;
    if (!(items[(*count)++] = strdup (item)))
        die ("strdup failed");
}

static int
is_app (const char *path)
{
    size_t length = strlen (path);
    return length > 4 && !strcmp (path + length - 4, ".app");
}

static void
scan_app_roots (size_t *count)
{
    char user_apps[PATH_MAX];
    const char *roots[] = {
        "/Applications",
        "/System/Applications",
        "/System/Library/CoreServices",
        "/Network/Applications",
        user_apps,
        NULL,
    };
    if (snprintf (user_apps, sizeof user_apps, "%s/Applications", home)
        >= (int)sizeof user_apps)
        return;

    FTS *tree
        = fts_open ((char *const *)roots, FTS_PHYSICAL | FTS_NOCHDIR, NULL);
    if (!tree)
        return;
    FTSENT *entry;
    while ((entry = fts_read (tree))) {
        if (entry->fts_info != FTS_D)
            continue;
        if (!is_app (entry->fts_path))
            continue;
        add_item (entry->fts_path, count);
        fts_set (tree, entry, FTS_SKIP);
    }
    fts_close (tree);
}

static void
print_cache (void)
{
    char buffer[BUFSIZ];
    FILE *cache = fopen (CACHE, "r");
    if (!cache)
        die ("open cache failed");
    char *cached_path = NULL;
    size_t size = 0;
    if (getline (&cached_path, &size, cache) < 0)
        die ("read cache failed");
    free (cached_path);
    while (fgets (buffer, sizeof buffer, cache))
        fputs (buffer, stdout);
    if (ferror (cache))
        die ("read cache failed");
    fclose (cache);
}

static void
scan (void)
{
    char buffer[PATH_MAX];
    char directory_buffer[PATH_MAX];
    const char *cursor = path, *directory;
    size_t count = 0;
    while ((directory = next_path_directory (
                &cursor, directory_buffer, sizeof directory_buffer))) {
        DIR *dir = opendir (directory);
        if (!dir)
            continue;
        struct dirent *entry;
        while ((entry = readdir (dir))) {
            struct stat status;
            if (entry->d_name[0] == '.')
                continue;
            if (snprintf (buffer, sizeof buffer, "%s/%s", directory,
                          entry->d_name)
                    >= (int)sizeof buffer
                || stat (buffer, &status) < 0 || !S_ISREG (status.st_mode)
                || access (buffer, X_OK) < 0)
                continue;
            add_item (entry->d_name, &count);
        }
        closedir (dir);
    }
    scan_app_roots (&count);
    qsort (items, count, sizeof *items, qstrcmp);
    char temporary[] = CACHE ".XXXXXX";
    int fd = mkstemp (temporary);
    if (fd < 0)
        die ("create temporary cache failed");
    FILE *cache = fdopen (fd, "w");
    if (!cache) {
        close (fd);
        unlink (temporary);
        die ("open temporary cache failed");
    }
    int failed = fprintf (cache, "%s\n", path) < 0;
    for (size_t i = 0; i < count; i++) {
        if (i && !strcmp (items[i], items[i - 1]))
            continue;
        if (fprintf (cache, "%s\n", items[i]) < 0)
            failed = 1;
    }
    if (fclose (cache) == EOF)
        failed = 1;
    if (failed) {
        unlink (temporary);
        die ("write cache failed");
    }
    if (rename (temporary, CACHE) < 0) {
        unlink (temporary);
        die ("replace cache failed");
    }
    for (size_t i = 0; i < count; i++)
        free (items[i]);
    free (items);
    items = NULL;
    print_cache ();
}

int
main (void)
{
    if (!(home = getenv ("HOME")))
        die ("no $HOME");
    if (!(path = getenv ("PATH")))
        die ("no $PATH");
    if (!getcwd (working_directory, sizeof working_directory))
        die ("getcwd failed");
    if (chdir (home) < 0)
        die ("chdir failed");
    make_cache_dir ();
    if (uptodate ())
        print_cache ();
    else
        scan ();
    return EXIT_SUCCESS;
}
