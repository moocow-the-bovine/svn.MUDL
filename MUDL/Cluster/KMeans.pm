#-*- Mode: Perl -*-

## File: MUDL::Cluster::Kmeans.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description:
##  + MUDL unsupervised dependency learner
##======================================================================

package MUDL::Cluster::KMeans;
use Algorithm::Cluster qw(kcluster);
use MUDL::Object;
use Carp;

our @ISA = qw(MUDL::Object);
our @EXPORT_OK = qw();

##======================================================================
## K-Means clustering: Constructor

## $args = KMeans->new(%args);
##   + %args:
##       data     => \@data,   # 2d array ref (matrix), $n-by-$d
##       nclusters=> $k,       # number of desired clusters (default=2)
##       npass    => $npasses, # number of full k-means passes (default=1)
##       initialid=> \@vector, # initial cluster ids ($n-ary vector, values in [0..($k-1)])
##                             # - if given, implies npass=>1
##       mask     => \@mask,   # either '' or $n-by-$d boolean-valued matrix: true iff $data->[$i][$j] is missing
##       weight   => \@wts,    # either '' or $d-ary weight vector
##       tranpose => $bool,    # whether $data is row-primary (0,default) or column-primary (1)
##       dist     => $metric,  # distance metric character flag (default='e')
##       method   => $method,  # center computation method flag (default='a')
##   + additional data (after running):
##       clusters => \@clstrs, # $n-ary array, values in [0..($k-1)], gives cluster assignment
##       error    => $error,   # within-cluster sum of distances of the "optimal" solution found
##       nfound   => $nfound,  # number of times the "optimal" solution was found
##   + where:
##       $n : number of data instances (rows)
##       $d : number of features per datum (columns)
##   + methods:
##       'a' : arithmetic mean (default)
##       'm' : median
##   + metrics:
##       'c' : correlation
##       'a' : abs(correlation)
##       'u' : uncentered correlation
##       'x' : abs(uncentered correlation)
##       's' : Spearman's rank correlation
##       'k' : Kendalls tau
##       'e' : Euclidean distance
##       'b' : city-block (L1) distance
sub new {
  my $km = $_[0]->SUPER::new(
			     data=>[[]],
			     nclusters => 2,
			     npass=>1,
			     #initialid=>undef,
			     mask=>'',
			     weight=>'',
			     transpose=>0,
			     dist=>'e',
			     method=>'a',
			     ##-- output data
			     clusters=>undef,
			     error=>undef,
			     nfound=>0,
			     @_[1..$#_]
			    );

  return $km;
}


##======================================================================
## $km = $km->cluster(%args)
##  + actually runs clustering alg
sub cluster {
  my ($km,%args) = @_;
  @$km{keys(%args)} = values(%args);
  @$km{qw(clusters error nfound)} = Algorithm::Cluster::kcluster(%$km);
  return $km;
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
