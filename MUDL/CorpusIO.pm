##-*- Mode: Perl -*-

## File: MUDL::CorpusIO.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description:
##  + MUDL unsupervised dependency learner: corpora: I/O
##======================================================================

package MUDL::CorpusIO;
use MUDL::Object;
use MUDL::Token;
use MUDL::Sentence;
use IO::File;
use Carp;

our $VERSION = 0.01;

our @ISA = qw(MUDL::Object);

########################################################################
## I/O : Abstract: CorpusIO
########################################################################
package MUDL::CorpusIO;
use File::Basename;
use MUDL::Object qw(dummy);
use Carp;

## $cr = $class_or_object->fileReader($filename,%args)
##  + new reader for $filename
##  + $filename may be prefixed with 'fmt:'
our %FORMATS =
  (xml => 'XML',
   ttt  => 'TT',
   tt  => 'TT',
   t => 'TT',
   native => 'TT',
   tnt => 'TT',
   #DEFAULT => 'XML',
   DEFAULT => 'TT',
  );
*fileReader = \&formatReader;
sub formatReader {
  my ($that,$file,@args) = @_;
  my $class = "MUDL::CorpusReader::";
  my $fmt = 'DEFAULT';
  if ($file =~ s/^(\S+)://) {
    $fmt = $1;
  } else {
    foreach (keys(%FORMATS)) {
      if ("\L$file\E" =~ /\.$_$/) {
	$fmt = $_;
	last;
      }
    }
  }
  $class .= $FORMATS{$fmt};
  my $obj;
  if (ref($that) && UNIVERSAL::isa($that,$class)) {
    $obj = $that;
  } else {
    $obj = $class->new(@args);
  }
  $obj->fromFile($file);
  return $obj;
}

## $cr = $class_or_object->fileWriter($filename,%args)
##  + new writer for $filename
##  + $filename may be prefixed with '${FORMAT}:'
*fileWriter = \&formatWriter;
sub formatWriter {
  my ($that,$file,@args) = @_;
  my $class = "MUDL::CorpusWriter::";
  my $fmt = 'DEFAULT';
  if ($file =~ s/^(\S+)://) {
    $fmt = $1;
  }
  else {
    foreach (keys(%FORMATS)) {
      if ("\L$file\E" =~ /\.$_$/) {
	$fmt = $_;
	last;
      }
    }
  }
  $class .= $FORMATS{$fmt};
  my $obj;
  if (ref($that) && UNIVERSAL::isa($that,$class)) {
    $obj = $that;
  } else {
    $obj = $class->new(@args);
  }
  $obj->toFile($file);
  return $obj;
}


########################################################################
## I/O : Abstract: Corpus Reader
########################################################################
package MUDL::CorpusReader;
use Carp;
our @ISA = qw(MUDL::CorpusIO);
MUDL::Object->import('dummy');

## $bool = $cr->eof
*eof = dummy('eof');

## \@sentence = $cr->getSentence();
*getSentence = dummy('getSentence');

## \%token_or_undef = $cr->getToken();
*getToken = dummy('getToken');

## undef = $cr->fromString($string)
*fromString = dummy('fromString');

## undef = $cr->fromFile($filename_or_fh);
*fromFile = dummy('fromFile');
*fromFh = dummy('fromFh');

## $n = $cr->nSentences()
*nSentences = *nSents = *nsents = dummy('nSentences');

## undef = $cr->reset()
*reset = dummy('reset');

## $n = $cr->nTokens()
*nTokens = *nToks = *ntoks = dummy('nTokens');

########################################################################
## I/O : Abstract: Corpus Writer
########################################################################
package MUDL::CorpusWriter;
use Carp;
MUDL::Object->import('dummy');
our @ISA = qw(MUDL::CorpusIO);

## $bool = $cw->flush
*flush = dummy('flush');

## undef = $cw->putSentence(\@sent);
*putSentence = dummy('putSentence');

## undef = $cr->putToken($text_or_hashref);
*putToken = dummy('putToken');

## undef = $cr->toString(\$string)
*toString = dummy('toString');

## undef = $cr->toFile($filename_or_fh);
*toFile = dummy('toFile');
*toFh = dummy('toFh');

########################################################################
## I/O : TT : Reader
########################################################################
package MUDL::CorpusReader::TT;
use Carp;
MUDL::Object->import('dummy');
our @ISA = qw(MUDL::CorpusReader);

sub new {
  my ($that,%args) = @_;
  my $self = bless {
		    allow_empty_sentences=>0,
		    nsents=>0,
		    ntoks=>0,
		    %args,
		   }, ref($that)||$that;
  return $self;
}

sub DESTROY {
  my $cr = shift;
  $cr->{fh}->close if (defined($cr->{fh}));
}

## $n = nSentences()
*nSents = *nsents = \&nSentences;
sub nSentences { return $_[0]->{nsents}; }

## $n = $cr->nTokens()
*nToks = *ntoks = \&nTokens;
sub nTokens { return $_[0]->{ntoks}; }

## reset()
sub reset {
  $_[0]{nsents} = $_[0]{ntoks} = 0;
  $_[0]{fh}->close if (defined($_[0]{fh}));
}

## $bool = $cr->eof
sub eof { return !$_[0]->{fh} || $_[0]->{fh}->eof; }

## undef = $cr->fromString($str)
sub fromString {
  my ($cr,$string) = @_;
  $cr->{fh}->close() if (defined($cr->{fh}));
  $cr->{fh} = IO::Scalar->new(\$string)
    or croak( __PACKAGE__ , "::fromString(): open failed: $!");
  binmode($cr->{fh}, ':utf8');
}

## undef = $cr->fromFile($filename)
## undef = $cr->fromFh($fh)
*fromFh = \&fromFile;
sub fromFile {
  my ($cr,$file) = @_;
  $cr->{fh}->close() if (defined($cr->{fh}));
  $cr->{fh} = ref($file) ? $file : IO::File->new("<$file");
  croak( __PACKAGE__ , "::fromFile(): open failed for '$file': $!") if (!$cr->{fh});
  binmode($cr->{fh}, ':utf8');
}

## \@sentence_or_undef = $cr->getSentence();
sub getSentence {
  my ($cr,%args) = @_;
  return undef if (!$cr->{fh} || $cr->{fh}->eof);
  %args = (allow_empty_sentences=>0,%args);

  my ($line);
  my $sent = bless [], 'MUDL::Sentence';
  while (defined($line=$cr->{fh}->getline)) {
    chomp $line;
    next if ($line =~ /^\%\%/);
    if ($line =~ /^\s*$/) {
      if (@$sent || $args{allow_empty_sentences}) {
	$cr->{nsents}++;
	return $sent;
      }
      next;
    }
    push(@$sent, bless [ split(/\s*\t+\s*/, $line) ], 'MUDL::Token::TT');
    $cr->{ntoks}++;
  }
  if (@$sent || $args{allow_empty_sentences}) {
    $cr->{nsents}++;
    return $sent;
  }
  return undef;
}

## \%token_or_undef = $cr->getToken();
sub getToken {
  my ($cr,%args) = @_;
  return undef if (!$cr->{fh} || $cr->{fh}->eof);

  my ($line);
  while (defined($line=$cr->{fh}->getline)) {
    chomp $line;
    next if ($line =~ /^\%\%/);
    if ($line eq '') {
      $cr->{nsents}++;
      return undef;
    }

    $cr->{ntoks}++;
    return bless [split(/\s*\t+\s*/, $line)], 'MUDL::Token::TT';
  }
  return undef;
}



########################################################################
## I/O : TT : Writer
########################################################################
package MUDL::CorpusWriter::TT;
use Carp;
MUDL::Object->import('dummy');
our @ISA = qw(MUDL::CorpusWriter);


## $cw = class->new(%args)
##   + known %args:
##      layers => \@binmode_layer_flags
sub new {
  my ($that,%args) = @_;
  my $cw = bless { layers=>[qw(:utf8)], %args }, ref($that)||$that;
  return $cw;
}

sub DESTROY {
  my $cw = shift;
  $cr->{fh}->close if (defined($cr->{fh}));
}

## $bool = $cw->flush
sub flush { return $_[0]->{fh} ? $_[0]->{fh}->flush : undef; }

## undef = $cw->toString(\$str)
sub toString {
  my ($cw,$sref) = @_;
  $cw->{fh}->close() if (defined($cw->{fh}));
  $cw->{fh} = IO::Scalar->new(\$string)
    or croak( __PACKAGE__ , "::toString(): open failed: $!");
  binmode($cw->{fh}, $_) foreach (@{$cw->{layers}});
}

## undef = $cw->toFile($filename_or_fh)
*toFh = \&toFile;
sub toFile {
  my ($cw,$file) = @_;
  $cw->{fh}->close() if (defined($cw->{fh}));
  $cw->{fh} = ref($file) ? $file : IO::File->new(">$file");
  croak( __PACKAGE__ , "::toFile(): open failed for '$file': $!") if (!$cw->{fh});
  binmode($cw->{fh}, $_) foreach (@{$cw->{layers}});
}

## undef = $cw->putSentence(\@sent);
sub putSentence {
  my ($cw,$sent) = @_;
  return undef if (!$cw->{fh});

  my $fh = $cw->{fh};
  my ($tok);
  foreach $tok (@$sent) {
    if (ref($tok)) {
      $fh->print($tok->saveNativeString);
      #$fh->print(join("\t", $tok->{text}, @{$tok->{details}}), "\n");
    } else {
      $fh->print($tok, "\n");
    }
  }
  $fh->print("\n");
}

## undef = $cw->putToken($text_or_hashref)
sub putToken {
  my ($cw,$token) = @_;
  return undef if (!$cr->{fh});

  if (ref($token)) {
    $cw->{fh}->print($tok->saveNativeString);
    #$cw->{fh}->print(join("\t", $tok->{text}, @{$tok->{details}}), "\n");
  } elsif (defined($token)) {
    #$cw->{fh}->print($tok, "\n");
    $cw->{fh}->print($tok, "\n");
  } else {
    $cw->{fh}->print("\n");
  }
}


########################################################################
## I/O : XML : Reader
########################################################################
package MUDL::CorpusReader::XML;
use Carp;
MUDL::Object->import('dummy');
MUDL::XML->import(qw(:xpaths :styles));
our @ISA = qw(MUDL::CorpusReader);

our %TokenClasses =
  (
   'raw' => 'MUDL::Token::Raw',
   'tt' => 'MUDL::Token::TT',
   'xml' => 'MUDL::Token::XML',
   'token' => 'MUDL::Token',
   'default' => 'MUDL::Token::XML',
  );

## new(%args)
sub new {
  my ($that,%args) = @_;
  my $self = bless {
		    tokenClass => 'default', ##-- token subclass to generate

		    s_xpath => $s_xpath,
		    token_xpath => $token_xpath,
		    text_xpath => $text_xpath,
		    detail_xpath => $detail_xpath,
		    tag_xpath => $tag_xpath,
		
		    s_elt => 's',
		    token_elt => 'token',
		    text_elt => 'text',
		    detail_elt => 'detail',
		    tag_elt => 'tag',

		    xmlparser => MUDL::XML::Parser->new(),
		    snodes => [], ##-- remaining sentence nodes
		    sentbuf => undef, ##-- sentence buffer for getToken
		    nsents => 0,
		    ntoks => 0,
		    %args,
		   }, ref($that)||$that;

  if (!$self->{stylesheet}) {
    my $style = $self->{style} ? $self->{sytle} : stylesheet_xml2norm(%$self);
    my $xslt  = XML::LibXSLT->new();
    my $sdoc  = $self->{xmlparser}->parse_string($style)
      or croak( __PACKAGE__ , "::new(): could not parse stylesheet document: $!");
    $self->{stylesheet} = $xslt->parse_stylesheet($sdoc)
      or croak( __PACKAGE__ , "::new(): could not parse stylesheet: $!");
  }

  ##-- token class
  if (defined($TokenClasses{"\L$self->{tokenClass}\E"})) {
    $self->{tokenClass} = $TokenClasses{"\L$self->{tokenClass}\E"};
  } else {
    carp( __PACKAGE__ , "::new(): unknown tokenClass '$self->{tokenClass}' -- using default.");
    $self->{tokenClass} = $TokenClasses{default};
  }

  return $self;
}

## $n = nSentences()
*nSents = *nsents = \&nSentences;
sub nSentences { return $_[0]->{nsents}; }

## $n = $cr->nTokens()
*nToks = *ntoks = \&nTokens;
sub nTokens { return $_[0]->{ntoks}; }

## reset()
sub reset {
  $_[0]{nsents} = $_[0]{ntoks} = 0;
  $_[0]{doc} = undef;
}


## $bool = $cr->eof
sub eof { return !$_[0]->{snodes} && !$_[0]->{sentbuf}; }

## undef = $cr->fromString($string)
sub fromString {
  my ($cr,$str) = @_;
  $cr->{doc} = $cr->{xmlparser}->parse_string($string)
    or croak( __PACKAGE__ , "::fromString(): parse failed: $!");
  if ($cr->{stylesheet}) {
    $cr->{doc} = $cr->{stylesheet}->transform($cr->{doc})
      or croak( __PACKAGE__ , "::fromString(): transform failed: $!");
  }
  @{$cr->{snodes}} = $cr->{doc}->documentElement->getChildrenByTagName($cr->{s_elt});
  $cr->{nsents} = scalar(@{$cr->{snodes}});
}

## undef = $cr->fromFile($filename_or_fh);
sub fromFile {
  my ($cr,$file) = @_;
  if (ref($file)) {
    $cr->{doc} = $cr->{xmlparser}->parse_fh($file)
      or croak( __PACKAGE__ , "::fromFile(): parse failed for filehandle: $!");
  } else {
    $cr->{doc} = $cr->{xmlparser}->parse_file($file)
      or croak( __PACKAGE__ , "::fromFile(): parse failed for file '$file': $!");
  }
  if ($cr->{stylesheet}) {
    $cr->{doc} = $cr->{stylesheet}->transform($cr->{doc})
      or croak( __PACKAGE__ , "::fromString(): transform failed: $!");
  }
  @{$cr->{snodes}} = $cr->{doc}->documentElement->getChildrenByTagName($cr->{s_elt});
  $cr->{nsents} = scalar(@{$cr->{snodes}});
}

## undef = $cr->fromFh($fh);
sub fromFh {
  my ($cr,$fh) = @_;
  $cr->{doc} = $cr->{xmlparser}->parse_fh($fh)
    or croak( __PACKAGE__ , "::fromFh(): parse failed for filehandle: $!");

  if ($cr->{stylesheet}) {
    $cr->{doc} = $cr->{stylesheet}->transform($cr->{doc})
      or croak( __PACKAGE__ , "::fromString(): transform failed: $!");
  }
  @{$cr->{snodes}} = $cr->{doc}->documentElement->getChildrenByTagName($cr->{s_elt});
  $cr->{nsents} = scalar(@{$cr->{snodes}});
}


## \@sentence = $cr->getSentence();
#select(STDERR); $|=1; select(STDOUT);
sub getSentence {
  my $cr = shift;
  return undef if (!$cr->{doc} || !@{$cr->{snodes}});

  #print STDERR ".";

  if ($cr->{sentbuf}) {
    my $sent = $cr->{sentbuf};
    $cr->{sentbuf} = undef;
    return $sent;
  }

  my $snode = shift(@{$cr->{snodes}});
  my $sent = bless [], 'MUDL::Sentence';
  foreach my $toknode ($snode->getChildrenByTagName($cr->{token_elt})) {
    $cr->{ntoks}++;
    push(@$sent, $cr->{tokenClass}->fromCorpusXMLNode($toknode));
  }
  return $sent;
}

## \%token_or_undef = $cr->getToken();
sub getToken {
  my $cr = shift;
  return undef if (!$cr->{doc} || !@{$cr->{snodes}});

  if ($cr->{sentbuf}) {
    if (@{$cr->{sentbuf}}) {
      $cr->{ntoks}++;
      return shift(@{$cr->{sentbuf}});
    }
  }
  $cr->{sentbuf} = $cr->getSentence;
  return undef;
}


########################################################################
## I/O : XML : Writer
########################################################################
package MUDL::CorpusWriter::XML;
use Carp;
MUDL::Object->import('dummy');
our @ISA = qw(MUDL::CorpusWriter);

## new(%args)
sub new {
  my ($that,%args) = @_;
  my $self = bless {
		    s_elt => 's',
		    token_elt => 'token',
		    text_elt => 'text',
		    detail_elt => 'detail',

		    attr2elt => {}, ##-- attribute-to-element-name conversion

		    tag_elt => 'tag',
		    root_elt => 'MUDL.Corpus',
		    flush => undef, ##-- flushing sub
		    xmlencoding => 'UTF-8',
		    xmlversion => '1.0',
		    %args,
		   }, ref($that)||$that;

  return $self;
}

## $bool = $cw->flush
sub flush {
  my $cw = shift;
  return $cw->{flush} ? &{$cw->{flush}}($cw) : undef;
}

## undef = $cw->toString(\$str)
sub toString {
  my ($cw,$sref) = @_;
  my $doc  = $cw->{doc} = XML::LibXML::Document->new($cw->{xmlversion}, $cw->{xmlencoding});
  $doc->setDocumentElement($cw->{root}=XML::LibXML::Element->new($cw->{root_elt}));
  $cw->{flush} =
    sub {
      my $cw = shift;
      if (defined($cw->{doc})) {
	$cw->{doc}->setCompression($cw->{compress}) if (defined($cw->{compress}));
	$$sref = $cw->{doc}->toString($cw->{format});
      }
    };
}

## undef = $cw->toFile($filename)
sub toFile {
  my ($cw,$file) = @_;
  my $doc  = $cw->{doc} = XML::LibXML::Document->new($cw->{xmlversion}, $cw->{xmlencoding});
  $doc->setDocumentElement($cw->{root}=XML::LibXML::Element->new($cw->{root_elt}));
  $cw->{flush} =
    sub {
      my $cw = shift;
      if (defined($cw->{doc})) {
	$cw->{doc}->setCompression($cw->{compress}) if (defined($cw->{compress}));
	$cw->{doc}->toFile($file, $cw->{format});
      }
    };
}

## undef = $cw->toFh($fh)
sub toFh {
  my ($cw,$file) = @_;
  my $doc  = $cw->{doc} = XML::LibXML::Document->new($cw->{xmlversion}, $cw->{xmlencoding});
  $doc->setDocumentElement($cw->{root}=XML::LibXML::Element->new($cw->{root_elt}));
  $cw->{flush} =
    sub {
      my $cw = shift;
      if (defined($cw->{doc})) {
	$cw->{doc}->setCompression($cw->{compress}) if (defined($cw->{compress}));
	$cw->{doc}->toFH($file, $cw->{format});
      }
    };
}

## undef = $cw->putSentence(\@sent);
sub putSentence {
  my ($cw,$sent) = @_;
  return undef if (!$cw->{doc});

  my ($snode,$tok);
  $cw->{root}->appendChild($snode=XML::LibXML::Element->new($cw->{s_elt}));
  foreach $tok (@$sent) {
    $snode->appendChild($tok->toCorpusXMLNode());
  }
}
sub putSentenceOld {
  my ($cw,$sent) = @_;
  return undef if (!$cw->{doc});

  my ($snode,$tok,$toknode,$tag, $akey,$aval,$a_elt,$anode);
  $cw->{root}->appendChild($snode=XML::LibXML::Element->new($cw->{s_elt}));
  foreach $tok (@$sent) {
    $snode->appendChild($toknode = XML::LibXML::Element->new($cw->{token_elt}));
    if (ref($tok)) {
      $toknode->appendTextChild($cw->{text_elt}, $tok->text);
      $toknode->appendTextChild($cw->{tag_elt}, $tag) if (defined($tag=$tok->tag));
      foreach $akey ($tok->attributeNames) {
	$a_elt = $cw->{attr2elt}{$akey};
	$a_elt = $cw->{detail_elt} if (!defined($a_elt));
	$anode = XML::LibXML::Element->new($a_elt);
	$anode->setAttribute('key',$akey);
	$anode->appendText($tok->attribute($akey));
	$toknode->appendChild($anode);
      }
    } else {
      $toknode->appendTextChild($cw->{text_elt}, $tok);
    }
  }
}

## undef = $cw->putToken($text_or_hashref)
#sub putToken

########################################################################
## I/O : Memory : CorpusReader
########################################################################

package MUDL::CorpusIO::Corpus;
use MUDL::Corpus;
use MUDL::Object;
use Carp;
our @ISA = qw(MUDL::CorpusReader MUDL::CorpusWriter);

## $cr = $cr->fromCorpus($mudl_corpus)
*toCorpus = \&fromCorpus;
sub fromCorpus { $_[0]{corpus} = $_[1]; }

## undef = $cr->reset
sub reset {
  @{$_[0]}{qw(pos nsents ntoks)} = (0,0,0);
  #$_[0]{corpus} = undef;
}

## $n = $cr->nSentences
*nSents = *nsents = \&nSentences;
sub nSentences { return $_[0]{nsents}; }

## $n = $cr->nTokens
*nToks = *ntoks = \&nTokens;
sub nTokens { return $_[0]{ntoks}; }

## $bool = $cr->eof;
sub eof {
  my $cr = shift;
  return (!$cr->{corpus} || $cr->{pos} == @{$cr->{corpus}{sents}});
}

## $s = $cr->getSentence
sub getSentence {
  my $cr = shift;
  return undef if ($cr->eof);
  my $s = $cr->{corpus}{sents}[$cr->{pos}++];
  ++$cr->{nsents};
  $cr->{ntoks} += @$s;
  return $s;
}

## $t = $cr->getToken
##-- not implemented

##--------------------
## Writer Methods

## $bool = $cw->flush
sub flush { ; }

## undef = $cw->putSentence
sub putSentence {
  my ($cw,$s) = @_;
  $cw->{corpus} = MUDL::Corpus->new() if (!$cw->{corpus});
  push(@{$cw->{corpus}{sents}}, $s);
}

## undef = $cw->putToken
##-- not implemented

##-- aliases
package MUDL::CorpusReader::Corpus;  our @ISA=qw(MUDL::CorpusIO::Corpus);
package MUDL::CorpusWriter::Corpus;  our @ISA=qw(MUDL::CorpusIO::Corpus);

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
