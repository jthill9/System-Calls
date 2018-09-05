/* moveit.c: Interactive Move Command */

#include <errno.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <fcntl.h>
#include <sys/wait.h>
#include <unistd.h>

/* Macros */

#define	streq(a, b) (strcmp(a, b) == 0)
#define strchomp(s) (s)[strlen(s) - 1] = 0

/* Functions */

/**
 * Display usage message and exit.
 * @param   progname    Program name.
 * @param   status      Exit status.
 */
void	usage(const char *progname, int status) {
    fprintf(stderr, "Usage: %s files...\n", progname);
    exit(status);
}

/**
 * Save list of file paths to temporary file.
 * @param   files       Array of path strings.
 * @param   n           Number of path strings.
 * @return  Newly allocated path to temporary file.
 */
char *	save_files(char **files, size_t n) {
    char* name = strdup("tempmoveit.XXXXXX");

    int fd = mkstemp(name);
    if (fd < 0) {
        return NULL;
    }

    FILE* file = fdopen(fd, "w+");
    if (!file) {
        fclose(file);
        return NULL;
    }

    for (size_t i = 0; i < n; i++) {
        fprintf(file, "%s\n", files[i]);
    }
    fclose(file);
    return name;
}

/**
 * Run $EDITOR on specified path.
 * @param   path        Path to file to edit.
 * @return  Whether or not the $EDITOR process terminated successfully.
 */
bool	edit_files(const char *path) {
    int status;

    char* editor = getenv("EDITOR");
    if (editor == NULL) {
        editor = "vim";
    }
    pid_t pid = fork();

    if (pid < 0) {
        fprintf(stderr, "Unable to fork: %s\n", strerror(errno));
        return false;
    }
    if (pid == 0) {
	    if (execlp(editor, editor, path, NULL) < 0) {
            fprintf(stderr, "Unable to exec: %s\n", strerror(errno));
	        return false;
	    }
    }
    else {
	    while ((pid = wait(&status)) < 0);
        if (WIFEXITED(status)) {
            status = WEXITSTATUS(status);
        }
        else {
            status = WTERMSIG(status);
        }
    }
    return (status == 0);
}

/**
 * Rename files as specified in contents of path.
 * @param   files       Array of old path names.
 * @param   n           Number of old path names.
 * @param   path        Path to file with new names.
 * @return  Whether or not all rename operations were successful.
 */
bool	move_files(char **files, size_t n, const char *path) {
    FILE* file = fopen(path, "r");
    if (!file) {
        return false;
    }
    char buffer[BUFSIZ];
    for (size_t i = 0; i < n; i++) {
        if (fgets(buffer, BUFSIZ, file) > 0) {
            strchomp(buffer);
            if (!streq(files[i], buffer)) {
                if (rename(files[i], buffer) < 0) {
                    return false;
                }
            }
        }
    }
    fclose(file);
    return true;
}

/* Main Execution */

int	main(int argc, char *argv[]) {
    char* file_names[argc - 1];
    if (argc == 1 || streq(argv[1], "-h")) {
        usage(argv[0], 1);
    }
    int num_files = argc - 1;
    for (int i = 0; i < num_files; i++) {
        file_names[i] = argv[i + 1];
    }

    char* path = save_files(file_names, num_files);

    if (!path) {
        unlink(path);
        free(path);
        return EXIT_FAILURE;
    }
    if (!edit_files(path)) {
        unlink(path);
        free(path);
        return EXIT_FAILURE;
    }
    if (!move_files(file_names, num_files, path)) {
        unlink(path);
        free(path);
        return EXIT_FAILURE;
    }
    unlink(path);
    free(path);
    return EXIT_SUCCESS;
}

/* vim: set sts=4 sw=4 ts=8 expandtab ft=c: */
