#
# Copyright (c) 2010-2013 by Nils Görs <weechatter@arcor.de>
# Copyleft (ɔ) 2013 by oakkitten
#
# colors the channel text with nick color and also highlight the whole line
# colorize_nicks2.py script will be supported
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# with version 3.0 some options were renamed or have new possible values:
# old:                  new:
# avail_buffer          buffer
# blacklist_channels    blacklist_buffers
# highlight             new values

# obsolete options:
# buffer_autoset
# hotlist_max_level_nicks_add
# highlight_regex
# highlight_words
# shuffle
# chat                  see option highlight

# i recommend to remove all colorize_lines options, first:
# /script unload colorize_lines
# /unset plugins.var.perl.colorize_lines.*
# /unset plugins.desc.perl.colorize_lines*
# /script load colorize_lines.pl

# history:
# 3.2: minor logic fix
# 3.1: fix: line wasn't colored with nick color, when highlight option was "off" (reported by rivarun)
# 3.0: large part of script rewritten
#      fix: works nicely with colors
#      improved: highlight_regex and highlight_words work in a natural way
#      removed: /colorize_lines
#      removed: shuffle
# 2.2: fix: regex with [tab] in message (patch by sqrrl)
# 2.1: fix: changing highlight color did not apply messages already displayed (reported by rafi_)
# 2.0: fix: debugging weechat::print() removed (thanks demure)
# 1.9: fix: display bug with nick_mode
# 1.8  add: option "use_irc_colors" (requested by Zertap)
#      fix: empty char for nick_mode was used, even when "irc.look.nick_mode_empty" was OFF (reported by FlashCode)
# 1.7: fix: broken lines in dcc chat (reported by equatorping)
# 1.6: improved: wildcard "*" can be used for server and/or nick. (requested by ldvx)
#    : add: new value, "only", for option "own_lines" (read help!)
# 1.5: sync: option weechat.look.nickmode changed in 0.3.9 to "irc.look.nick_mode"
# 1.4: fix: whole ctcp message was display in prefix (reported by : Mkaysi)
# 1.3: fix: now using weechat::buffer_get_string() instead of regex to prevent problems with dots inside server-/channelnames (reported by surfhai)
# 1.2: add: hook_modifier("colorize_lines") to use colorize_lines with another script.
#    : fix: regex was too greedy and also hit tag "prefix_nick_ccc"
# 1.1: fix:  problems with temporary server (reported by nand`)
#    : improved: using weechat_string_has_highlight()
# 1.0: fix: irc.look.nick_prefix wasn't supported
# 0.9: added: option "own_nick" (idea by travkin)
#    : new value (always) for option highlight
#    : clean up code
# 0.8.1: fix: regex()
# 0.8: added: option "avail_buffer" and "nicks" (please read help-page) (suggested by ldvx)
#    : fix: blacklist_buffers wasn't load at start
#    : fix: nick_modes wasn't displayed since v0.7
#    : rewrote init() routine
#    : thanks to stfn for hint with unescaped variables in regex.
# 0.7: fix: bug when irc.look.nick_suffix was set (reported and beta-testing by: hw2) (>= weechat 0.3.4)
#      blacklist_buffers option supports servername
#      clean up code
# 0.6: code optimazations.
#      rename of script (rainbow_text.pl -> colorize_lines.pl) (suggested by xt and flashcode)
# 0.5: support of hotlist_max_level_nicks_add and weechat.color.chat_nick_colors (>= weechat 0.3.4)
# 0.4: support of weechat.look.highlight_regex option (>= weechat 0.3.4)
#    : support of weechat.look.highlight option
#    : highlighted line did not work with "." inside servername
#    ; internal "autoset" function fixed
# 0.3: support of colorize_nicks.py implemented.
#    : /me text displayed wrong nick colour (colour from suffix was used)
#    : highlight messages will be checked case insensitiv
# 0.2: supports highlight_words_add from buffer_autoset.py script (suggested: Emralegna)
#    : correct look_nickmode colour will be used (bug reported by: Emralegna)
#    : /me text will be coloured, too
# 0.1: initial release
#
# Development is currently hosted at
# https://github.com/weechatter/weechat-scripts
#
# requirements: sunglasses ;-)

#use Data::Dumper
#$Data::Dumper::Useqq=1;

use strict;
my $prgname	= "colorize_lines2";
my $version	= "3.2";
my $description	= "colors text in chat area with according nick color, including highlights";

my %config = ("buffers"             => "all",       # all, channel, query
              "blacklist_buffers"   => "",          # "a,b,c"
              "lines"               => "on",
              "highlight"           => "on",        # on, off, nicks
              "nicks"               => "",          # "d,e,f", "/file"
              "own_lines"           => "on",        # on, off, only
);

my %help_desc = ("buffers"             => "buffer type affected by the script (all/channel/query, default: all)",
                 "blacklist_buffers"   => "comma-separated list of channels to be ignored (e.g. freenode.#weechat,*.#python)",
                 "lines"               => "apply nickname color to the lines (off/on/nicks). the latter will limit highlighting to nicknames in option 'nicks'",
                 "highlight"           => "apply highlight color to the highlighted lines (off/on/nicks). the latter will limit highlighting to nicknames in option 'nicks'",
                 "nicks"               => "comma-separater list of nicks (e.g. freenode.cat,*.dog) OR file name starting with '/' (e.g. /file.txt). in the latter case, nicknames will get loaded from that file inside weechat folder (e.g. from ~/.weechat/file.txt). nicknames in file are newline-separated (e.g. freenode.dog\\n*.cat)",
                 "own_lines"           => "apply nickname color to own lines (off/on/only). the latter turns off all other kinds of coloring altogether",
);

#################################################################################################### config

# program starts here
sub colorize_cb {
    my ( $data, $modifier, $modifier_data, $string ) = @_;

    # quit if it's not a privmsg or ctcp
    # or we are not supposed to
    if ((index($modifier_data,"irc_privmsg") == -1) ||
        (index($modifier_data,"irc_ctcp") >= 0)) {
        return $string;
    }

    # find buffer pointer
    $modifier_data =~ m/([^;]*);([^;]*);/;
    my $buffer = weechat::buffer_search($1, $2);
    return $string if ($buffer eq "");

    # find buffer name, server name
    # return if buffer is in a blacklist
    my $buffername = weechat::buffer_get_string($buffer, "name");
    return $string if weechat::string_has_highlight($buffername, $config{blacklist_buffers});
    my $servername = weechat::buffer_get_string($buffer, "localvar_server");

    # find stuff between \t
    $string =~ m/^([^\t]*)\t(.*)/;
    my $left = $1;
    my $right = $2;

    # find nick of the sender
    # find out if we are doing an action
    my $nick = ($modifier_data =~ m/(^|,)nick_([^,]*)/) ? $2 : weechat::string_remove_color($left, "");
    my $action = ($modifier_data =~ m/\birc_action\b/) ? 1 : 0;

    ######################################## get color

    my $color = "";
    my $my_nick = weechat::buffer_get_string($buffer, "localvar_nick");
    if ($my_nick eq $nick) {
        # it's our own line
        # process only if own_lines is "on" or "only" (i.e. not "off")
        return $string if ($config{own_lines} eq "off");
        $color = weechat::color("chat_nick_self");
    } else {
        # it's someone else's line
        # don't process is own_lines are "only"
        # in order to get correct matching, remove colors from the string
        return $string if ($config{own_lines} eq "only");
        my $right_nocolor = weechat::string_remove_color($right, "");
        if ((
            # if configuration wants us to highlight
            $config{highlight} eq "on" ||
            ($config{highlight} eq "nicks" && weechat::string_has_highlight("$servername.$nick", $config{nicks}))
           ) && (
            # ..and if we have anything to highlight
            weechat::string_has_highlight($right_nocolor, weechat::buffer_string_replace_local_var($buffer, weechat::buffer_get_string($buffer, "highlight_words"))) ||
            weechat::string_has_highlight($right_nocolor, weechat::config_string(weechat::config_get("weechat.look.highlight"))) ||
            weechat::string_has_highlight_regex($right_nocolor, weechat::config_string(weechat::config_get("weechat.look.highlight_regex"))) ||
            weechat::string_has_highlight_regex($right_nocolor, weechat::buffer_get_string($buffer, "highlight_regex"))
           )) {
            # that's definitely a highlight! get a hilight color
            # and replace the first occurance of coloring, that'd be nick color
            $color = weechat::color('chat_highlight');
            $right =~ s/\31[^\31 ]+?\Q$nick/$color$nick/ if ($action);
        } elsif (
            # now that's not a highlight OR highlight is off OR current nick is not in the list
            # let's see if configuration wants us to highlight lines
            $config{lines} eq "on" ||
            ($config{lines} eq "nicks" && weechat::string_has_highlight("$servername.$nick", $config{nicks}))
           ) {
            $color = weechat::info_get('irc_nick_color', $nick);
        } else {
            # oh well
            return $string;
        }
    }

    ######################################## inject colors and go!

    my $out = "";
    if ($action) {
        # remove the first color reset - after * nick
        # make other resets reset to our color
        $right =~ s/\34//;
        $right =~ s/\34/\34$color/g;
        $out = $left . "\t" . $right . "\34"
    } else {
        # make other resets reset to our color
        $right =~ s/\34/\34$color/g;
        $out = $left . "\t" . $color . $right . "\34"
    }
    #weechat::print("", ""); weechat::print("", "\$str " . Dumper($string)); weechat::print("", "\$out " . Dumper($out));
    return $out;
}

#################################################################################################### config

# read nicknames if $conf{nisks} starts with /
# after this, $conf{nisks} is of form a,b,c,d
# if it doesnt start with /, assume it's already a,b,c,d
sub nicklist_read {
    return if (substr($config{nicks}, 0, 1) ne "/");
    my $file = weechat::info_get("weechat_dir", "") . $config{nicks};
    return unless -e $file;
    my $nili = "";
    open (WL, "<", $file) || DEBUG("$file: $!");
    while (<WL>) {
        chomp;                                                         # kill LF
        $nili .= $_ . ",";
    }
    close WL;
    chop $nili;                                                        # remove last ","
    $config{nicks} = $nili;
}

# called when a config option ha been changed
# $name = plugins.var.perl.$prgname.nicks etc
sub toggle_config_by_set {
    my ($pointer, $name, $value) = @_;
    $name = substr($name,length("plugins.var.perl.$prgname."),length($name));
    $config{$name} = lc($value);
    nicklist_read() if ($name eq "nicks");
}

# read configuration from weechat OR
#   set default options and
#   set dectription if weechat >= 0.3.5
# after done, read nicklist from file if needed
sub init_config {
    my $weechat_version = weechat::info_get('version_number', '') || 0;
    foreach my $option (keys %config){
        if (!weechat::config_is_set_plugin($option)) {
            weechat::config_set_plugin($option, $config{$option});
            weechat::config_set_desc_plugin($option, $help_desc{$option}) if ($weechat_version >= 0x00030500); # v0.3.5
        } else {
            $config{$option} = lc(weechat::config_get_plugin($option));
        }
    }
    nicklist_read();
}

#################################################################################################### start

weechat::register($prgname, "Nils Görs <weechatter\@arcor.de>", $version, "GPL3", $description, "", "");
weechat::hook_modifier("500|weechat_print","colorize_cb", "");
init_config();
weechat::hook_config("plugins.var.perl.$prgname.*", "toggle_config_by_set", "");