# Copyright (C) 2010      Andrew Clunis <andrew@orospakr.ca>
#                         Daniel Rubin <dan@fracturedproject.net>
#               2005-2009 Quentin Sculo <squentin@free.fr>
#
# This file is part of Gmusicbrowser.
# Gmusicbrowser is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 3, as
# published by the Free Software Foundation

=gmbplugin EPICRATING
name    EpicRating
title   EpicRating plugin - automatically update ratings
author  Andrew Clunis <andrew@orospakr.ca>
author  Daniel Rubin <dan@fracturedproject.net>
desc    Automatic rating updates on configurable listening behaviour events.
=cut

package GMB::Plugin::EPICRATING;
use strict;
use warnings;

use constant {
    OPT => 'PLUGIN_EPICRATING_',#used to identify the plugin's options
    ALWAYS_AVAILABLE => ["PlayingID"],
    EVENTS => {played => ["PlayTime", "PlayedPercent"]},
    ACTIONS => ["REMOVE_FROM_RATING", "ADD_TO_RATING", "RATING_SET_TO_DEFAULT"]
};

::SetDefaultOptions(OPT, RatingOnSkip => -5, GracePeriod => 15, RatingOnSkipBeforeGrace => -1, RatingOnPlayed => 5, SetDefaultRatingOnSkipped => 1, SetDefaultRatingOnPlayed => 1, MyHash => { a => "a", b => "actually b"}, Rules => {internet => 42});

my $self=bless {},__PACKAGE__;

sub AddRatingPointsToSong {
    my $ID=$_[0];
    my $PointsToRemove = $_[1];
    my $ExistingRating = ::Songs::Get($ID, 'rating');
    if(($ExistingRating + $PointsToRemove) > 100)
    {
        warn "Yikes, can't rate this song above one hundred.";
        ::Songs::Set($ID, rating=>100);
    } elsif(($ExistingRating + $PointsToRemove) < 0) {
        warn "Negaive addend in EpicRating pushed song rating to below 0.  Pinning.";
        ::Songs::Set($ID, rating => 0);
    } else {
        warn "EpicRating changing song rating by " . $PointsToRemove;
        ::Songs::Set($ID, rating=>($ExistingRating + $PointsToRemove));
    }
}

sub Played {
        my $ID=$::PlayingID;
        my $DefaultRating = $::Options{"DefaultRating"};
        my $GracePeriod = $::Options{OPT.'GracePeriod'};
        my $RatingOnSkip = $::Options{OPT.'RatingOnSkip'};
        my $RatingOnSkipBeforeGrace = $::Options{OPT.'RatingOnSkipBeforeGrace'};
        my $RatingOnPlayed = $::Options{OPT.'RatingOnPlayed'};

        if(!defined $::PlayTime) {
            warn "EpicRating's Played callback is missing PlayTime?!";
            return;
        }
        my $PlayedPartial=$::PlayTime-$::StartedAt < $::Options{PlayedPercent} * ::Songs::Get($ID,'length');
        if ($PlayedPartial)
        {
                my $song_rating = Songs::Get($ID, 'rating');
                if(($song_rating eq "") && $::Options{OPT."SetDefaultRatingOnSkipped"}) {
                    ::Songs::Set($ID, rating=>$DefaultRating);
                } elsif(!$song_rating) {
                    # user didn't have the setting on
                    return;
                } else {
                    if(($GracePeriod != 0) && ($::PlayTime < $GracePeriod)) {
                        AddRatingPointsToSong($ID, $RatingOnSkipBeforeGrace);
                    } else {
                        AddRatingPointsToSong($ID, $RatingOnSkip);
                    }
                }
        } else {
                my $song_rating = ::Songs::Get($ID, 'rating');
                if(($song_rating eq "") && $::Options{OPT."SetDefaultRatingOnPlayed"}) {
                    ::Songs::Set($ID, rating=>$DefaultRating);
                } elsif(!$song_rating) {
                    # user didn't have the setting on
                    return;
                }
                AddRatingPointsToSong($ID, $RatingOnPlayed);
        }
}

sub Start {
    ::Watch($self, Played => \&Played);

}

sub Stop {
    ::UnWatch($self, $_) for qw/Played/;
}

sub AddRow {
    my $rule = $_[0];


    my $button = Gtk2::Button->new("lolwhut: " . $rule);
    $self->{rules_table}->attach($button, 0, 1, $self->{current_row}, $self->{current_row}+1, "shrink", "shrink", 0, 0);
    $self->{current_row} += 1;
}

sub prefbox {
    # TODO validate good values?E!??!
    my $big_vbox = Gtk2::VBox->new(::FALSE, 2);
    my $rules_scroller = Gtk2::ScrolledWindow->new();
    $rules_scroller->set_policy('never', 'automatic');
    $self->{rules_table} = Gtk2::Table->new(1, 4, ::FALSE);
    $rules_scroller->add_with_viewport($self->{rules_table});

    # my $test_button = Gtk2::Button->new("you smell");
    # $self->{rules_table}->attach($test_button, 0, 1, 0, 1, "shrink", "shrink", 0, 0); #expand, shrink, or fill?

    # my $test_button2 = Gtk2::Button->new("you smell2");
    # $self->{rules_table}->attach($test_button2, 0, 1, 1, 2, "shrink", "shrink", 0, 0); #expand, shrink, or fill?


    # reset counters
    # iterate over existing rules and Add 'em.




    $self->{current_row} = 0;
#    warn $::Options{OPT.'Rules'}->values->join(', ');

    my $rules = $::Options{OPT.'Rules'};

    # ${$rules}{"internet"} = 45;

    # use Data::Dumper qw( Dumper );
    # print STDERR "The hash is " . Dumper( $rules ) . "\n";


    warn "attempting to extract keys from hash ref: " . $rules;

    foreach my $key (keys %{$rules}) {
        my $rule_settings = ${$rules}{$key};
        AddRow($key);
    }

    # my $sg1=Gtk2::SizeGroup->new('horizontal');
    # my $sg2=Gtk2::SizeGroup->new('horizontal');

    # # rating change on skip
    # # rating change on full play
    # # if less than 15% in there somehow

    # my $grace_period_entry = ::NewPrefEntry(OPT."GracePeriod",
    #                                         _"Grace period:",
    #                                         sizeg1 => $sg1,sizeg2=>$sg2,
    #                                         tip => _"grace period denoting a 'fast' skip in which to apply a different addend, in seconds; if zero, grace period does not apply");
    # my $rating_on_skip_entry = ::NewPrefSpinButton(OPT.'RatingOnSkip',
    #                                                -100, 100,
    #                                                sizeg1 => $sg1,sizeg2=>$sg2,,
    #                                                text1 => _"Add to rating on skip:");
    # my $rating_on_skip_before_grace_entry = ::NewPrefSpinButton(OPT.'RatingOnSkipBeforeGrace',
    #                                                             -100, 100,
    #                                                             sizeg1 => $sg1,sizeg2=>$sg2,
    #                                                             text1 => _"Add to rating on skip (before grace period):");
    # my $rating_on_played_entry = ::NewPrefSpinButton(OPT.'RatingOnPlayed',
    #                                                  -100, 100,
    #                                                  sizeg1 => $sg1,sizeg2=>$sg2,
    #                                                  text1 => _"Add to rating on played completely:");

    # my $set_default_rating_label = Gtk2::Label->new(_"Apply your default rating to files when they are first played (required for rating update on files with default rating):");
    # my $set_default_rating_skip_check = ::NewPrefCheckButton(OPT."SetDefaultRatingOnSkipped",
    #                                                         _"... on skipped songs",);
    # my $set_default_rating_played_check = ::NewPrefCheckButton(OPT."SetDefaultRatingOnPlayed",
    #                                                           _"... on played songs");

    # $big_vbox->pack_start($_, ::FALSE, ::FALSE, 0) for $grace_period_entry, $rating_on_skip_entry, $rating_on_skip_before_grace_entry, $rating_on_played_entry, $set_default_rating_label, $set_default_rating_skip_check, $set_default_rating_played_check;
    $big_vbox->add($rules_scroller);

    $big_vbox->show_all();
    return $big_vbox;
}
