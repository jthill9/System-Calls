#!/bin/bash

PROGRAM=moveit
WORKSPACE=/tmp/$PROGRAM.$(id -u)
FAILURES=0

export PATH=$WORKSPACE:$PATH

if [ -n "$EDITOR" ]; then
    export EDITOR=$(basename $EDITOR)
fi

# Functions

error() {
    echo "$@"
    [ -r $WORKSPACE/test ] && (echo; cat $WORKSPACE/test; ls -l $WORKSPACE; echo)
    FAILURES=$((FAILURES + 1))
}

cleanup() {
    STATUS=${1:-$FAILURES}
    rm -fr $WORKSPACE
    exit $STATUS
}

make_files() {
    for file in $@; do
    	echo "$file" > $WORKSPACE/$file
    done
}

make_editor() {
    echo '#!/bin/sh'         > $WORKSPACE/editor
    echo 'truncate -s 0 $1' >> $WORKSPACE/editor
    for file in $@; do
	echo "echo $WORKSPACE/$file >> \$1" >> $WORKSPACE/editor
    done
    chmod +x $WORKSPACE/editor
    ln -sf $WORKSPACE/editor $WORKSPACE/vim
    ln -sf $WORKSPACE/editor $WORKSPACE/nano
    ln -sf $WORKSPACE/editor $WORKSPACE/emacs
}

prefix_files() {
    echo $@ | awk -v W=$WORKSPACE '{ for (i = 1; i <= NF; i++) { print W "/" $i }}'
}

test_files() {
    cat > $WORKSPACE/check <<EOF
import os
import sys
WORKSPACE = sys.argv[1]
OLD_FILES = sys.argv[2].split()
NEW_FILES = sys.argv[3].split()

for old_name, new_name in zip(OLD_FILES, NEW_FILES):
    new_path = os.path.join(WORKSPACE, new_name)
    if not os.path.exists(new_path):
        print('Missing {}'.format(new_path))
        sys.exit(1)

    new_data = open(new_path).read().strip()
    if new_data != old_name:
        print('{} has wrong contents: {} != {}'.format(new_path, new_data, old_name))
        sys.exit(1)

    print('Renamed {} -> {}'.format(old_name, new_name))

sys.exit(0)
EOF
    python3 $WORKSPACE/check $WORKSPACE "$old_files" "$new_files" &>> $WORKSPACE/test
}

test_valgrind() {
    if [ $(awk '/ERROR SUMMARY:/ {errors += $4} END{print errors}' $WORKSPACE/test) -ne 0 ]; then
	error "Failure"
    else
	echo "Success"
    fi
}

grep_all() {
    for pattern in $1; do
    	if ! grep -q -E "$pattern" $2; then
    	    echo "Missing $pattern in $2" >> $WORKSPACE/test
    	    return 1;
    	fi
    done
    return 0;
}

# Setup

mkdir $WORKSPACE

trap "cleanup" EXIT
trap "cleanup 1" INT TERM

# Testing

echo "Testing $PROGRAM..."

printf " %-72s ... " "system calls"
if ! grep_all "fork exec[vl]p (wait|waitpid) rename mkstemp getenv unlink" $PROGRAM.c; then
    error "Failure"
else
    echo "Success"
fi

printf " %-72s ... " "usage"
valgrind --leak-check=full ./$PROGRAM -h &> $WORKSPACE/test
if ! grep -q -i usage $WORKSPACE/test; then
    error "Failure"
else
    echo "Success"
fi

printf " %-72s ... " "usage (no arguments)"
valgrind --leak-check=full ./$PROGRAM &> $WORKSPACE/test
if ! grep -q -i usage $WORKSPACE/test; then
    error "Failure"
else
    echo "Success"
fi

printf " %-72s ... " "usage (valgrind)"
if [ $(awk '/ERROR SUMMARY:/ {print $4}' $WORKSPACE/test) -ne 0 ]; then
    error "Failure"
else
    echo "Success"
fi

old_files="deadpool spidey rogue"
new_files="deadpool spidey rogue"
printf " %-72s ... " "$old_files -> $new_files"
make_files $old_files && \
    make_editor $new_files && \
    valgrind --leak-check=full ./$PROGRAM $(prefix_files $old_files) &> $WORKSPACE/test
if [ $? -ne 0 ] || ! test_files; then
    error "Failure"
else
    echo "Success"
fi
printf " %-72s ... " "$old_files -> $new_files (valgrind)"
test_valgrind
rm -f $(prefix_files $old_files $new_files)

printf " %-72s ... " "$old_files -> $new_files (vim)"
make_files $old_files && \
    make_editor $new_files && \
    env EDITOR=vim valgrind --leak-check=full ./$PROGRAM $(prefix_files $old_files) &> $WORKSPACE/test
if [ $? -ne 0 ] || ! test_files; then
    error "Failure"
else
    echo "Success"
fi
printf " %-72s ... " "$old_files -> $new_files (vim, valgrind)"
test_valgrind
rm -f $(prefix_files $old_files $new_files)

printf " %-72s ... " "$old_files -> $new_files (nano)"
make_files $old_files && \
    make_editor $new_files && \
    env EDITOR=nano valgrind --leak-check=full ./$PROGRAM $(prefix_files $old_files) &> $WORKSPACE/test
if [ $? -ne 0 ] || ! test_files; then
    error "Failure"
else
    echo "Success"
fi
printf " %-72s ... " "$old_files -> $new_files (nano, valgrind)"
test_valgrind
rm -f $(prefix_files $old_files $new_files)

printf " %-72s ... " "$old_files -> $new_files (emacs)"
make_files $old_files && \
    make_editor $new_files && \
    env EDITOR=emacs valgrind --leak-check=full ./$PROGRAM $(prefix_files $old_files) &> $WORKSPACE/test
if [ $? -ne 0 ] || ! test_files; then
    error "Failure"
else
    echo "Success"
fi
printf " %-72s ... " "$old_files -> $new_files (emacs, valgrind)"
test_valgrind
rm -f $(prefix_files $old_files $new_files)

printf " %-72s ... " "$old_files -> $new_files (NOPE)"
make_files $old_files && \
    make_editor $new_files && \
    env EDITOR=NOPE valgrind --leak-check=full ./$PROGRAM $(prefix_files $old_files) &> $WORKSPACE/test
if [ $? -eq 0 ] || ! test_files; then
    error "Failure"
else
    echo "Success"
fi
printf " %-72s ... " "$old_files -> $new_files (NOPE, valgrind)"
test_valgrind
rm -f $(prefix_files $old_files $new_files)

old_files="deadpool spidey rogue"
new_files="batman superman wonderwoman"
printf " %-72s ... " "$old_files -> $new_files"
make_files $old_files && \
    make_editor $new_files && \
    valgrind --leak-check=full ./$PROGRAM $(prefix_files $old_files) &> $WORKSPACE/test
if [ $? -ne 0 ] || ! test_files; then
    error "Failure"
else
    echo "Success"
fi
printf " %-72s ... " "$old_files -> $new_files (valgrind)"
test_valgrind
rm -f $(prefix_files $old_files $new_files)

printf " %-72s ... " "$old_files -> $new_files (NOPE)"
make_files $old_files && \
    make_editor $new_files && \
    env EDITOR=NOPE valgrind --leak-check=full ./$PROGRAM $(prefix_files $old_files) &> $WORKSPACE/test
if [ $? -eq 0 ] || test_files; then
    error "Failure"
else
    echo "Success"
fi
printf " %-72s ... " "$old_files -> $new_files (NOPE, valgrind)"
test_valgrind
rm -f $(prefix_files $old_files $new_files)

old_files="batman superman wonderwoman"
new_files="deadpool batman rogue"
printf " %-72s ... " "$old_files -> $new_files"
make_files $old_files && \
    make_editor $new_files && \
    valgrind --leak-check=full ./$PROGRAM $(prefix_files $old_files) &> $WORKSPACE/test
if [ $? -ne 0 ] || ! test_files; then
    error "Failure"
else
    echo "Success"
fi
printf " %-72s ... " "$old_files -> $new_files (valgrind)"
test_valgrind
rm -f $(prefix_files $old_files $new_files)

printf " %-72s ... " "$old_files -> $new_files (NOPE)"
make_files $old_files && \
    make_editor $new_files && \
    env EDITOR=NOPE valgrind --leak-check=full ./$PROGRAM $(prefix_files $old_files) &> $WORKSPACE/test
if [ $? -eq 0 ] || test_files; then
    error "Failure"
else
    echo "Success"
fi
printf " %-72s ... " "$old_files -> $new_files (NOPE, valgrind)"
test_valgrind
rm -f $(prefix_files $old_files $new_files)


old_files="batman superman"
new_files="deadpool spidey rogue"
printf " %-72s ... " "$old_files -> $new_files"
make_files $old_files && \
    make_editor $new_files && \
    valgrind --leak-check=full ./$PROGRAM $(prefix_files $old_files) &> $WORKSPACE/test
if [ $? -ne 0 ] || ! test_files; then
    error "Failure"
else
    echo "Success"
fi
printf " %-72s ... " "$old_files -> $new_files (valgrind)"
test_valgrind
rm -f $(prefix_files $old_files $new_files)

printf " %-72s ... " "$old_files -> $new_files (NOPE)"
make_files $old_files && \
    make_editor $new_files && \
    env EDITOR=NOPE valgrind --leak-check=full ./$PROGRAM $(prefix_files $old_files) &> $WORKSPACE/test
if [ $? -eq 0 ] || test_files; then
    error "Failure"
else
    echo "Success"
fi
printf " %-72s ... " "$old_files -> $new_files (NOPE, valgrind)"
test_valgrind
rm -f $(prefix_files $old_files $new_files)


old_files="deadpool spidey rogue"
new_files="batman superman"
printf " %-72s ... " "$old_files -> $new_files"
make_files $old_files && \
    make_editor $new_files && \
    valgrind --leak-check=full ./$PROGRAM $(prefix_files $old_files) &> $WORKSPACE/test
if [ $? -ne 0 ] || ! test_files; then
    error "Failure"
else
    echo "Success"
fi
printf " %-72s ... " "$old_files -> $new_files (valgrind)"
test_valgrind
rm -f $(prefix_files $old_files $new_files)

printf " %-72s ... " "$old_files -> $new_files (NOPE)"
make_files $old_files && \
    make_editor $new_files && \
    env EDITOR=NOPE valgrind --leak-check=full ./$PROGRAM $(prefix_files $old_files) &> $WORKSPACE/test
if [ $? -eq 0 ] || test_files; then
    error "Failure"
else
    echo "Success"
fi
printf " %-72s ... " "$old_files -> $new_files (NOPE, valgrind)"
test_valgrind
rm -f $(prefix_files $old_files $new_files)

old_files="doom"
new_files="thing"
printf " %-72s ... " "$old_files -> $new_files"
make_editor $new_files && \
    valgrind --leak-check=full ./$PROGRAM $(prefix_files $old_files) &> $WORKSPACE/test
if [ $? -eq 0 ] || test_files; then
    error "Failure"
else
    echo "Success"
fi
printf " %-72s ... " "$old_files -> $new_files (valgrind)"
test_valgrind
rm -f $(prefix_files $old_files $new_files)

old_files="doom"
new_files="thing"
printf " %-72s ... " "$old_files -> $new_files (rm)"
env EDITOR="rm" valgrind --leak-check=full ./$PROGRAM $(prefix_files $old_files) &> $WORKSPACE/test
if [ $? -eq 0 ] || test_files; then
    error "Failure"
else
    echo "Success"
fi
printf " %-72s ... " "$old_files -> $new_files (rm, valgrind)"
test_valgrind
rm -f $(prefix_files $old_files $new_files)

old_files="doom"
new_files="thing"
printf " %-72s ... " "$old_files -> $new_files (false)"
env EDITOR="false" valgrind --leak-check=full ./$PROGRAM $(prefix_files $old_files) &> $WORKSPACE/test
if [ $? -eq 0 ] || test_files; then
    error "Failure"
else
    echo "Success"
fi
printf " %-72s ... " "$old_files -> $new_files (false, valgrind)"
test_valgrind
rm -f $(prefix_files $old_files $new_files)

TESTS=$(($(grep -c Success $0) - 1 + $(grep -c test_valgrind $0) - 2))
echo "   Score $(echo "scale=2; ($TESTS - $FAILURES) / $TESTS.0 * 7.00" | bc | awk '{printf "%0.2f\n", $0}')"
echo
