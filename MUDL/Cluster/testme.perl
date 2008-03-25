#!/usr/bin/perl -wd

use lib qw(../..);
use MUDL;
use MUDL::CmdUtils;
use PDL;
use PDL::Cluster;
use MUDL::PDL::Stats;
use MUDL::PDL::Ranks;
use MUDL::Cluster::Method;
use MUDL::Cluster::Tree;
use MUDL::Cluster::Buckshot;
use MUDL::Cluster::Distance;
use Benchmark qw(cmpthese timethese);

use MUDL::Corpus::MetaProfile::Attach;

BEGIN { $, = ' '; }

##----------------------------------------------------------------------
## test: perl distance func
##----------------------------------------------------------------------

#use MUDL::Cluster::Distance::L1;
#use MUDL::Cluster::Distance::L2;
#use MUDL::Cluster::Distance::Pearson;
sub test_perl_distance {
  my $data = pdl(double,[ [1,2,3,4],[1,3,2,1],[4,3,2,1] ]);
  my ($d,$n) = $data->dims;
  my $mask   = ones(long,$d,$n);
  my $wt     = ones(double,$d);

  ##-- what to compare?
  #my ($class,$dflag) = ('L1','b'); ##-- ok
  #my ($class,$dflag) = ('L2','e'); ##-- ok (but PDL::Cluster 'e' is missing sqrt() step)
  #my ($class,$dflag) = ('Pearson','c'); ##-- ok
  #my ($class,$dflag) = ('Cosine','u'); ##-- ok
  my ($class,$dflag) = ('Spearman','s'); ##-- ?

  my $cd = MUDL::Cluster::Distance->new(class=>$class);
  my ($rows1,$rows2) = cmp_pairs($n)->qsortvec->xchg(0,1)->dog;
  my $cmpvec   = $cd->compare(data1=>$data,data2=>$data,rows1=>$rows1,rows2=>$rows2);
  my $dmat     = $cd->distanceMatrix(data=>$data);

  ##-- get data matrix using builtin funcs
  my ($dmatb);
  if ($dflag ne 's') {
    $dmatb = distancematrix($data,$mask,$wt, $dflag);
  } else {
    $dmatb = distancematrix($data->ranks,$mask,$wt, 'c');
  }
  print STDERR "dmat(class=$class)==dmat(flag=$dflag) ? ", (all($dmat->approx($dmatb)) ? "ok" : "NOT ok"), "\n";

  print STDERR "$0: test_perl_distance() done: what now?\n";
}
test_perl_distance();

## ($i1,$i2)     = cmp_pairs($n) ##-- list context
## pdl(2,$ncmps) = cmp_pairs($n) ##-- scalar context; returned pdl is as for whichND()
##  + returns all index pairs ($i1,$i2) s.t. 0 <= $i1 < $i2 < $n
##  + stupid-but-easy version using sequence(), less-than, and whichND()
sub cmp_pairs_v0 {
  my $n = shift;
  my $cmp_wnd  = (sequence(long,$n) < sequence(long,1,$n))->whichND();
  return wantarray ? ($cmp_wnd->xchg(0,1)->dog) : $cmp_wnd;
}

## ($i1,$i2)     = cmp_pairs($n) ##-- list context
## pdl(2,$ncmps) = cmp_pairs($n) ##-- scalar context; returned pdl is as for whichND()
##  + returns all index pairs ($i1,$i2) s.t. 0 <= $i1 < $i2 < $n
##  + smarter & a bit faster for medium-to-large $n [faster at ca. $n >= 16]
BEGIN { *cmp_pairs = \&cmp_pairs_v1; }
sub cmp_pairs_v1 {
  my $n = shift;
  my $ncmps     = ($n/2)*($n-1);
  my $cmp0_vals = sequence(long,$n);#->reshape($ncmps);
  my $cmp0_runl = sequence(long,$n)->slice("-1:0");#->reshape($ncmps);
  my ($cmp0,$cmp0_lens);
  $cmp0_runl->rld($cmp0_vals, $cmp0     =zeroes(long,$ncmps));
  $cmp0_runl->rld($cmp0_runl, $cmp0_lens=zeroes(long,$ncmps));
  my $cmp1 = 1 + $cmp0 + ($cmp0->sequence->slice("-1:0") % $cmp0_lens);
  return wantarray ? ($cmp0,$cmp1) : $cmp0->cat($cmp1)->xchg(0,1);
}

##----------------------------------------------------------------------
## test data
use vars qw($k $n $d $data $mask $weight @dmw);
sub tdata {

  $data = pdl(double, [[1,1,1],[2,2,2],[3,3,3],[4,5,6],[7,8,9],[10,11,12]]) if (!defined($data));
  $d = $data->dim(0);
  $n = $data->dim(1);
  $k = 2 if (!defined($k));

  $mask = ones(long, $data->dims);
  $weight = ones(double, $d);
  @dmw = ($data,$mask,$weight);
}

##----------------------------------------------------------------------
## test random data
sub tdata_random {
  $n = 100 if (!defined($n));
  $d = 50  if (!defined($d));
  $k = 25  if (!defined($k));

  $data = random($d,$n);
  $mask = ones(long,$data->dims);
  $weight = ones(double,$d);
  @dmw = ($data,$mask,$weight);
}

##----------------------------------------------------------------------
## test cluster class
##  + requires: test data (tdata, tdata_random)
##  + usage: tcclass($class='Tree',%args)
sub tcclass {
  my $class = shift;
  $class = 'Tree' if (!defined($class));
  $niters = 0 if (!defined($niters));
  $cm = $tcclass{$class} = MUDL::Cluster::Method->new(class=>$class,
						      data=>$data,
						      mask=>$mask,
						      weight=>$weight,
						      niters=>$niters,
						      nclusters=>$k,
						      @_,
						     );
  $cm->cluster();
  $cm->cut();
}


##----------------------------------------------------------------------
## test prototypes
##   + requires: tdata()
use vars qw($np $protos $ptmp);
sub tprotos {
  $np = sclr(rint(sqrt($k*$n))) if (!$np);
  ($ptmp=random(float,$n))->minimum_n_ind($protos=zeroes(long,$np)-1);
  $protos .= qsort($protos);
}

##----------------------------------------------------------------------
## test prototypes: get data
##   + requires: tprotos()
use vars qw($pdata $pmask);
sub tpdata {
  $pdata = $data->dice_axis(1,$protos);
  $pmask = $mask->dice_axis(1,$protos);
}

##----------------------------------------------------------------------
## test prototypes: cluster 'em
##  + requires: tpdata()
use vars qw($ptree $plnkdist $pcids);
sub tpcluster {
  $pdist   = 'b' if (!defined($pdist));
  $pmethod = 'm' if (!defined($pmethod));

  ##-- cluster protos
  treecluster($pdata,$pmask,$weight,
	      ($ptree=zeroes(long,2,$np)),
	      ($plnkdist=zeroes(double,$np)),
	      $pdist, $pmethod);

  ##-- cut tree
  cuttree($ptree, $k, ($pcids=zeroes(long,$np)));
}


##----------------------------------------------------------------------
## test prototype centroid profiles
##  + requires: tpcluster()

##-- centroid profiles: means
use vars qw($pcmeans $pcmeansmask);
sub tpcmeans {
  getclustermean($pdata,$pmask,$pcids,
		 ($pcmeans=zeroes(double,$d,$k)),
		 ($pcmeansmask=zeroes(long,$d,$k)));

  ##-- centroid data: aliases
  $pcdata = $pcmeans;
  $pcmask = $pcmeansmask;
}

##-- centroid profiles: medians
use vars qw($pcmedians $pcmediansmask);
sub tpcmedians {
  getclustermedian($pdata,$pmask,$pcids,
		   ($pcmedians=zeroes(double,$d,$k)),
		   ($pcmediansmask=zeroes(long,$d,$k)));

  ##-- centroid data: aliases
  $pcdata = $pcmedians;
  $pcmask = $pcmediansmask;
}

##----------------------------------------------------------------------
## test prototype centroid profiles: weighted sum variants
##  + requires: tpcluster()

##-- get prototype cluster distance matrix
use vars qw($pcdm);
sub tpcmatrix {
  $cddist   = $pdist if (!defined($cddist));
  $cdmethod = 'x'    if (!defined($cdmethod));

  clustersizes($pcids, $pcsizes=zeroes(long,$k));
  clusterelements($pcids, $pcsizes, $pcelts=zeroes(long, $pcsizes->max, $k)-1);
  clusterdistancematrix($pdata,$pmask,$weight,
			sequence(long,$np), $pcsizes, $pcelts,
			$pcdm=zeroes(double,$k,$np),
			$cddist, $cdmethod);
}

##-- test m-best indices
## + requires: tpcmatrix
use vars qw($pcmbesti $pcmbestiND);
sub tpcmbesti {
 $m = 2 if (!defined($m));

 ##-- get minimum distance indices
 $pcmbesti = zeroes(long,$m,$k);
 $pcdm->xchg(0,1)->minimum_n_ind($pcmbesti);

 ##-- get values to keep
 $pcmbestiND = cat(yvals($pcmbesti)->flat, $pcmbesti->flat)->xchg(0,1);
}

##-- test m-best mask (soft)
## + requires: tpcmatrix
use vars qw($tpcmbestmask);
sub tpcmbestmask_soft {
  tpcmbesti;
  $pcmbestmask_soft = zeroes(byte, $pcdm->dims);
  $pcmbestmask_soft->indexND($pcmbestiND) .= 1;
  $pcmbestmask = pdl($pcmbestmask_soft);
}

##-- test m-best mask (hard)
## + requires: -
use vars qw($tpcmbestmask);
sub tpcmbestmask_hard {
  tpcmbestmask_soft;
  clusterelementmask($pcids, $pceltmask=zeroes(byte,$k,$np));
  $pcmbestmask_hard = $pcmbestmask_soft * $pceltmask;
  $pcmbestmask      = pdl($pcmbestmask_hard);
}

##-- test m-best mean (soft)
## + requires: tpcmatrix
sub tpcmbestmeans_soft {
  print STDERR "tpcmbestmeans_soft(): called.\n";

  tpcmbestmask_soft;
  $pcw  = zeroes(double, $pcdm->dims)+1/$m;
  $pcw *= $pcmbestmask;

  ##-- alt: given only tpcmbesti()
  #tpcmbesti;
  #$pcw = zeroes(double, $pcdm->dims); ##-- zero non-best values
  #$pcw->indexND($pcmbestiND) .= 1/$m; ##-- set weights for arithmetic mean

  #-- get centroid data
  getclusterwsum($pdata,$pmask, $pcw,
		 ($pcmbestmeans_soft_data=zeroes(double,$d,$k)),
		 ($pcmbestmeans_soft_mask=zeroes(long,$d,$k)));

  ##-- centroid data: aliases
  $pcdata = $pcmbestmeans_soft_data;
  $pcmask = $pcmbestmeans_soft_mask;
}


##-- test m-best mean (hard)
## + requires: tpcmatrix
sub tpcmbestmeans_hard {
  tpcmbestmask_hard;
  $pcw  = ones(double, $pcdm->dims);
  $pcw *= $pcmbestmask;
  $pcw /= $pcw->xchg(0,1)->sumover;

  #-- get centroid data
  getclusterwsum($pdata,$pmask, $pcw,
		 ($pcmbestmeans_hard_data=zeroes(double,$d,$k)),
		 ($pcmbestmeans_hard_mask=zeroes(long,$d,$k)),
		);

  ##-- centroid data: aliases
  $pcdata = $pcmbestmeans_hard_data;
  $pcmask = $pcmbestmeans_hard_mask;
}


##----------------------------------------------------------------------
## test prototype centroid profiles: weighted sum variants: inverse
##  + requires: tpcluster()

##-- test m-best inverse (soft)
## + requires: tpcmatrix
sub tpcmbestinverse_soft {
  tpcmbestmask_soft;

  $pcmimin = $pcdm->where($pcdm!=0)->flat->minimum if (!defined($pcmimin) || !sclr($pcmimin));
  $pcw     = $pcmimin / ($pcmimin+$pcdm);
  $pcw    *= $pcmbestmask;
  $pcw    /= $pcw->xchg(0,1)->sumover;

  #-- get centroid data
  getclusterwsum($pdata,$pmask, $pcw,
		 ($pcmbestinv_soft_data=zeroes(double,$d,$k)),
		 ($pcmbestinv_soft_mask=zeroes(long,$d,$k)));

  ##-- centroid data: aliases
  $pcdata = $pcmbestinv_soft_data;
  $pcmask = $pcmbestinv_soft_mask;
}

##-- test m-best inverse (hard)
## + requires: tpcmatrix
sub tpcmbestinverse_hard {
  tpcmbestmask_hard;

  $pcmimin = $pcdm->where($pcdm!=0)->flat->minimum if (!defined($pcmimin) || !sclr($pcmimin));
  $pcw     = $pcmimin / ($pcmimin+$pcdm);
  $pcw    *= $pcmbestmask;
  $pcw    /= $pcw->xchg(0,1)->sumover;

  #-- get centroid data
  getclusterwsum($pdata,$pmask, $pcw,
		 ($pcmbestinv_hard_data=zeroes(double,$d,$k)),
		 ($pcmbestinv_hard_mask=zeroes(long,$d,$k)));

  ##-- centroid data: aliases
  $pcdata = $pcmbestinv_hard_data;
  $pcmask = $pcmbestinv_hard_mask;
}


##----------------------------------------------------------------------
## test attachment
##  + requires: tpcluster(), $pcdata, $pcmask
##    i.e. tpc${method}(), e.g. tpcmeans(), tpcmbestinverse_hard(), ...
use vars qw($acdist $aceltmask);
sub tattach {
  ##-- dist? method?
  $adist   = $pdist if (!defined($adist));
  $amethod = 'x'    if (!defined($amethod));

  ##-- get attachment targets
  $apmask = zeroes(byte,$n);
  $apmask->index($protos) .= 1;
  $atmask = !$apmask;
  $atids  = $atmask->which;
  $na     = $atids->nelem;

  attachtonearest($data, $mask, $weight,
		  $atids,
		  $pcdata, $pcmask,
		  $acids=zeroes(long,$na),
		  $acdist=zeroes(double,$na),
		  $adist, $amethod);

  ##-- get grand total output
  $cids = zeroes(long,$n);
  $cids->index($protos) .= $pcids;
  $cids->index($atids)  .= $acids;

  ##-- ... and its mask
  clusterelementmask($cids, $aceltmask=zeroes(byte,$k,$n));
}

sub baddata {
  tdata;

  $protos = pdl(long,[2,3,4]);
  $np=$protos->nelem;
  $k=2;

  tpdata;
  tpcluster;
  tpcmeans;
  tattach;
}

sub itertest {
  $icsub = shift;
  $icsub = \&tpcmeans if (!defined($icsub));

  ##-- don't regen data
  tprotos;
  tpdata;
  tpcluster;
  tpcmatrix;
  clusterelementmask($pcids,$pceltmask=zeroes(long,$k,$np));

  &$icsub();
  tattach;

  print "pdata=$pdata, pcdata=$pcdata, pceltmask=$pceltmask, data=$data, aceltmask=$aceltmask\n";
}

##----------------------------------------------------------------------
## Buckshot
##----------------------------------------------------------------------
#use MUDL::Cluster::Method;
#use MUDL::Cluster::Buckshot;


##----------------------------------------------------------------------
## Dummy
##----------------------------------------------------------------------

#ltest1;
foreach $i (0..100) {
  print "--dummy[$i]--\n";
}
