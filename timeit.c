/* moveit.c: Interactive Move Command */

#include <errno.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include <fcntl.h>
#include <sys/time.h>
#include <sys/wait.h>
#include <unistd.h>

/* Macros */

#define	streq(a, b) (strcmp(a, b) == 0)
#define strchomp(s) (s)[strlen(s) - 1] = 0
#define debug(M, ...) \
    if (Verbose) { \
        fprintf(stderr, "%s:%d:%s: " M, __FILE__, __LINE__, __func__, ##__VA_ARGS__); \
    }

/* Globals */

int  Timeout = 10;
bool Verbose = false;

/* Functions */

/**
 * Display usage message and exit.
 * @param   progname    Program name.
 * @param   status      Exit status.
 */
void	usage(const char *progname, int status) {
    fprintf(stderr, "Usage: %s [options] command...\n", progname);
    fprintf(stderr, "Options:\n");
    fprintf(stderr, "    -t SECONDS  Timeout duration before killing command (default is %d)\n", Timeout);
    fprintf(stderr, "    -v          Display verbose debugging output\n");
    exit(status);
}

/**
 * Parse command line options.
 * @param   argc        Number of command line arguments.
 * @param   argv        Array of command line argument strings.
 * @return  Array of strings representing command to execute.
 */
char ** parse_options(int argc, char **argv) {
    if (argc == 1) {
        usage(argv[0], EXIT_FAILURE);
    }

    int argind = 1;

    while (argind < argc && strlen(argv[argind]) > 1 && argv[argind][0] == '-') {
        if (argv[argind][1] == 't') {
            Timeout = (int)strtol(argv[++argind], NULL, 10);
        }
        else if (argv[argind][1] == 'v') {
            Verbose = true;
        }
        else if (argv[argind][1] == 'h') {
            usage(argv[0], EXIT_SUCCESS);
        }
        else {
            usage(argv[0], EXIT_FAILURE);
        }
        argind++;
    }

    char** command = NULL;

    if  (argind < argc) {
        command = malloc((argc - argind + 1) * sizeof(char*));
            int i;
            for (i = argind; i < argc; i++) {
                command[i - argind] = argv[i];
            }
            command[i - argind] = NULL;
    }

    debug("Timeout = %d\n", Timeout);
    debug("Verbose = %d\n", Verbose);
    if (command == NULL) {
        return command;
    }
    if (command[0] && command[1]) {
        debug("Command = %s %s\n", command[0], command[1]);
    }
    else if (command[0]) {
        debug("Command = %s\n", command[0]);
    }

    return command;
}

/**
 * Handle signal.
 * @param   signum      Signal number.
 */
void    handle_signal(int signum) {
    debug("Received interrupt: %d\n", signum);
}

/* Main Execution */

int	main(int argc, char *argv[]) {
    char** commands = parse_options(argc, argv);
    struct timespec start, end;
    int status;
    if (commands == NULL) {
        usage(argv[0], EXIT_FAILURE);
    }
    debug("Registering handlers...\n");
    signal(SIGCHLD, handle_signal);

    debug("Grabbing start time...\n");
    clock_gettime(CLOCK_MONOTONIC, &start);
    pid_t pid = fork();

    if (pid < 0) { // Failure
        fprintf(stderr, "Unable to fork: %s\n", strerror(errno));
        free(commands);
        return EXIT_FAILURE;
    }
    if (pid == 0) { // Child
        debug("Executing child...\n");
	    if (execvp(commands[0], commands) < 0) {
            fprintf(stderr, "Unable to exec: %s\n", strerror(errno));
            free(commands);
	        return EXIT_FAILURE;
	    }
    }
    else { // Parent
        struct timespec tim;
        tim.tv_sec = Timeout;
        tim.tv_nsec = 0;
        debug("Sleeping for %d seconds...\n", Timeout);
        if (nanosleep(&tim, NULL) == 0){
            debug("Killing child %d\n", pid);
            kill(pid, 9);
        }

        debug("Waiting for child %d\n", pid);
	    wait(&status);
        if (WIFEXITED(status)) {
            status = WEXITSTATUS(status);
        }
        else {
            status = WTERMSIG(status);
        }
    }
    debug("Child exit status: %d\n", status);

    debug("Grabbing end time...\n");
    clock_gettime(CLOCK_MONOTONIC, &end);

    float diff = (end.tv_sec - start.tv_sec) + 0.000000001 * (end.tv_nsec - start.tv_nsec);
    printf("Time Elapsed: %.1f\n", diff);
    free(commands);
    return status;
}

/* vim: set sts=4 sw=4 ts=8 expandtab ft=c: */
