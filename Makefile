CC=		gcc
CFLAGS=		-g -gdwarf-2 -Wall -Werror -std=gnu99 -fPIC
LD=		gcc
LDFLAGS=	-L.
AR=		ar
ARFLAGS=	rcs
TARGETS=	moveit timeit

all:		$(TARGETS)

test:
	@$(MAKE) -sk test-all

test-all:	test-moveit test-timeit

test-moveit:	moveit
	@curl -sLO https://gitlab.com/nd-cse-20289-sp18/cse-20289-sp18-assignments/raw/master/homework09/test_moveit.sh
	@chmod +x test_moveit.sh
	@./test_moveit.sh

test-timeit:	timeit
	@curl -sLO https://gitlab.com/nd-cse-20289-sp18/cse-20289-sp18-assignments/raw/master/homework09/test_timeit.sh
	@chmod +x test_timeit.sh
	@./test_timeit.sh

clean:
	@echo Cleaning...
	@rm -f $(TARGETS) *.o

.SUFFIXES:

# TODO: Rules for moveit, timeit

moveit: moveit.c
	$(CC) $(CFLAGS) -o $@ $^

timeit: timeit.c
	$(CC) $(CFLAGS) -o $@ $^ -lrt
