use Test::More;
use Actions::Core;

$ENV{INPUT_BOOLEAN_INPUT} = 'true';
$ENV{INPUT_BOOLEAN_INPUT_TRUE1} = 'true';
$ENV{INPUT_BOOLEAN_INPUT_TRUE2} = 'True';
$ENV{INPUT_BOOLEAN_INPUT_TRUE3} = 'TRUE';
$ENV{INPUT_BOOLEAN_INPUT_FALSE1} = 'false';
$ENV{INPUT_BOOLEAN_INPUT_FALSE2} = 'False';
$ENV{INPUT_BOOLEAN_INPUT_FALSE3} = 'FALSE';
$ENV{INPUT_WRONG_BOOLEAN_INPUT} = 'wrong';

ok get_boolean_input('boolean input', { required => 1});
ok get_boolean_input('boolean input true1');
ok get_boolean_input('boolean input true2');
ok get_boolean_input('boolean input true3');
ok !get_boolean_input('boolean input false1');
ok !get_boolean_input('boolean input false2');
ok !get_boolean_input('boolean input false3');

eval {
    get_boolean_input('wrong boolean input');
};
like $@, qr/wrong boolean input/;

done_testing;
