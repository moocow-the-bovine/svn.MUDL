##-*- Mode: Perl -*-

## File: MUDL::Corpus::Profile::LRBigrams.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description:
##  + MUDL unsupervised dependency learner: corpus profile: L-R bigrams
##======================================================================

package MUDL::Corpus::Profile::LRBigrams;
use MUDL::Corpus::Profile::LR;
use MUDL::Object;
use PDL;
use Carp;
our @ISA = qw(MUDL::Corpus::Profile::LR);

##======================================================================
## $lr = $class_or_obj->new(%args)
##   + %args:
##       eos => $eos_str,
##       bos => $bos_str,
##       bounds => $bounds_enum,
##       targets => $targets_enum,
##       left=>$left_bigrams,       ## ($target,$lneighbor)
##       right=>$right_bigrams,     ## ($target,$rneighbor)
sub new {
  my ($that,%args) = @_; 
  return $that->SUPER::new(nfields=>1,donorm=>1,%args);
  return $self;
}

##======================================================================
## Profiling

## undef = $profile->addSentence(\@sentence)
sub addSentence {
  my ($pr,$s) = @_;

  ##-- sanity checks: bos/eos
  if (defined($pr->{bos})) {
    $pr->{bounds}->addSymbol($pr->{bos});
  }
  if (defined($pr->{eos})) {
    $pr->{bounds}->addSymbol($pr->{eos});
  }


  ##------ temporary sentence index profiles

  ##-- @st: sentence text
  my @st = ((defined($pr->{bos}) ? $pr->{bos} : qw()),
	    (map { $_->text } @$s),
	    (defined($pr->{eos}) ? $pr->{eos} : qw()));

  ##-- @tids, @bids: sentence target (bound) ids
  my @tids = map { $pr->{targets}{sym2id}{$_} } @st;
  my @bids = map { $pr->{bounds}{sym2id}{$_}  } @st;

  my $lbg = $pr->{left};
  my $rbg = $pr->{right};

  my ($i);
  for ($i=0; $i <= $#st; $i++) {
    next if (!defined($tid=$tids[$i]));

    ##-- left
    if ($i > 0 && defined($bid=$bids[$i-1])) {
      ++$lbg->{nz}{$tid.$lbg->{sep}.$bid};
    }

    ##-- right
    if ($i < $#st && defined($bid=$bids[$i+1])) {
      ++$rbg->{nz}{$tid.$rbg->{sep}.$bid};
    }
  }

  return $pr;
}




##======================================================================
## Conversion: to PDL

##-- inherited from MUDL:::Corpus::Profile::LR


##======================================================================
## Help

## $string = $class_or_obj->helpString()
sub helpString {
  my $that = shift;
  return
    (qq(Extract left- and right-bigram profile wrt. fixed boundary set.\n)
     .qq(Options:\n)
     .qq(  bounds=ENUM      [default=empty]\n)
     .qq(  targets=ENUM     [default=empty]\n)
     .qq(  eos=EOS_STRING   [default='__\$']\n)
     .qq(  bos=BOS_STRING   [default='__\$']\n)
     .qq(  donorm=BOOL      [default=1]\n)
    );
}

##======================================================================
## I/O: Native
## - (output only!)

## $bool = $obj->saveNativeFh($fh,%args)
sub saveNativeFh {
  my ($obj,$fh) = @_;
  $obj->{left}->toDist->saveNativeFh($fh,@_);
  $fh->print("\n\n\n");
  $obj->{right}->toDist->saveNativeFh($fh,@_);
  return $obj;
}


1;

##======================================================================
## Docs
=pod

=head1 NAME

MUDL - MUDL Unsupervised Dependency Learner

=head1 SYNOPSIS

 use MUDL;

=cut

##======================================================================
## Description
=pod

=head1 DESCRIPTION

...

=cut

##======================================================================
## Footer
=pod

=head1 ACKNOWLEDGEMENTS

perl by Larry Wall.

=head1 AUTHOR

Bryan Jurish E<lt>jurish@ling.uni-potsdam.deE<gt>

=head1 COPYRIGHT

Copyright (c) 2004, Bryan Jurish.  All rights reserved.

This package is free software.  You may redistribute it
and/or modify it under the same terms as Perl itself.

=head1 SEE ALSO

perl(1)

=cut
