\name{GAlignments-class}
\docType{class}

% Class:
\alias{class:GAlignments}
\alias{GAlignments-class}

\alias{parallel_slot_names,GAlignments-method}
\alias{updateObject,GAlignments-method}

% Accessors:
\alias{names,GAlignments-method}
\alias{seqnames,GAlignments-method}
\alias{rname}
\alias{rname,GAlignments-method}
\alias{strand,GAlignments-method}
\alias{names<-,GAlignments-method}
\alias{seqnames<-,GAlignments-method}
\alias{rname<-}
\alias{rname<-,GAlignments-method}
\alias{strand<-,GAlignments,ANY-method}
\alias{cigar}
\alias{cigar,GAlignments-method}
\alias{qwidth}
\alias{qwidth,GAlignments-method}
\alias{start,GAlignments-method}
\alias{width,GAlignments-method}
\alias{njunc}
\alias{njunc,GAlignments-method}
\alias{seqinfo,GAlignments-method}
\alias{seqinfo<-,GAlignments-method}

% Constructor:
\alias{GAlignments}
\alias{update,GAlignments-method}

% Coercion:
\alias{ranges,GAlignments-method}
\alias{granges,GAlignments-method}
\alias{grglist,GAlignments-method}
\alias{rglist,GAlignments-method}
\alias{coerce,GAlignments,IntegerRanges-method}
\alias{coerce,GAlignments,GRanges-method}
\alias{coerce,GAlignments,GRangesList-method}
\alias{coerce,GAlignments,IntegerRangesList-method}

\alias{coerce,GAlignments,DataFrame-method}
\alias{as.data.frame,GAlignments-method}

\alias{coerce,GenomicRanges,GAlignments-method}

% subsetting
\alias{getListElement,GAlignments-method}

% "show" method:
\alias{show,GAlignments-method}

% Concatenation:
\alias{bindROWS,GAlignments-method}

% Comparison/ordering:
\alias{pcompare,GAlignments,GAlignments-method}
\alias{is.unsorted,GAlignments-method}
\alias{order,GAlignments-method}
\alias{sort,GAlignments-method}
\alias{rank,GAlignments-method}


\title{GAlignments objects}

\description{
  The GAlignments class is a simple container which purpose is
  to store a set of genomic alignments that will hold just enough
  information for supporting the operations described below.
}

\details{
  A GAlignments object is a vector-like object where each element
  describes a genomic alignment i.e. how a given sequence (called "query"
  or "read", typically short) aligns to a reference sequence (typically
  long).

  Typically, a GAlignments object will be created by loading
  records from a BAM (or SAM) file and each element in the resulting
  object will correspond to a record. BAM/SAM records generally contain
  a lot of information but only part of that information is loaded
  in the GAlignments object. In particular, we discard the query
  sequences (SEQ field), the query qualities (QUAL), the mapping qualities
  (MAPQ) and any other information that is not needed in order to support
  the operations or methods described below.

  This means that multi-reads (i.e. reads with multiple hits in the
  reference) won't receive any special treatment i.e. the various SAM/BAM
  records corresponding to a multi-read will show up in the GAlignments
  object as if they were coming from different/unrelated queries.
  Also paired-end reads will be treated as single-end reads and the
  pairing information will be lost (see \code{?\link{GAlignmentPairs}}
  for how to handle aligned paired-end reads).

  Each element of a GAlignments object consists of:
  \itemize{
    \item The name of the reference sequence. (This is the RNAME field
          in a SAM/BAM record.)
    \item The strand in the reference sequence to which the query is
          aligned. (This information is stored in the FLAG field in a
          SAM/BAM record.)
    \item The CIGAR string in the "Extended CIGAR format" (see the SAM
          Format Specifications for the details).
    \item The 1-based leftmost position/coordinate of the clipped query
          relative to the reference sequence. We will refer to it as
          the "start" of the query. (This is the POS field in a SAM/BAM
          record.)
    \item The 1-based rightmost position/coordinate of the clipped query
          relative to the reference sequence. We will refer to it as
          the "end" of the query. (This is NOT explicitly stored in a
          SAM/BAM record but can be inferred from the POS and CIGAR fields.)
          Note that all positions/coordinates are always relative to
          the first base at the 5' end of the plus strand of the reference
          sequence, even when the query is aligned to the minus strand.
    \item The genomic intervals between the "start" and "end" of the query
          that are "covered" by the alignment. Saying that the full
          [start,end] interval is covered is the same as saying that the
          alignment contains no junction (no N in the CIGAR). It is then
          considered to be a simple alignment. Note that a simple alignment
          can have mismatches or deletions (in the reference). In other words,
          a deletion (encoded with a D in the CIGAR) is NOT considered to
          introduce a gap in the coverage, but a junction is.
  }

  Note that the last 2 items are not expicitly stored in the GAlignments
  object: they are inferred on-the-fly from the CIGAR and the "start".

  Optionally, a GAlignments object can have names (accessed thru the
  \code{\link[base]{names}} generic function) which will be coming from
  the QNAME field of the SAM/BAM records.

  The rest of this man page will focus on describing how to:
  \itemize{
    \item Access the information stored in a GAlignments object
          in a way that is independent from how the data are actually
          stored internally.
    \item How to create and manipulate a GAlignments object.
  }
}

\section{Constructor}{
  \describe{
    \item{\code{GAlignments(seqnames=Rle(factor()), pos=integer(0),
                            cigar=character(0),
                            strand=NULL, names=NULL,
                            ..., seqinfo=NULL, seqlengths=NULL)}:}{
      Low-level GAlignments constructor. Generally not used directly.
      Named arguments in \code{...} are used as metadata columns.
    }
  }
}

\section{Accessors}{
  In the code snippets below, \code{x} is a GAlignments object.

  \describe{
    \item{\code{length(x)}:}{
      Return the number of alignments in \code{x}.
    }
    \item{\code{names(x)}, \code{names(x) <- value}:}{
      Get or set the names on \code{x}.
      See \code{\link{readGAlignments}} for how to automatically extract
      and set the names when reading the alignments from a file.
    }
    \item{\code{seqnames(x)}, \code{seqnames(x) <- value}:}{
      Get or set the name of the reference sequence for each alignment
      in \code{x} (see Details section above for more information about
      the RNAME field of a SAM/BAM file).
      \code{value} can be a factor, or a 'factor' \link[S4Vectors]{Rle},
      or a character vector.
    }
    \item{\code{rname(x)}, \code{rname(x) <- value}:}{
      Same as \code{seqnames(x)} and \code{seqnames(x) <- value}.
    }
    \item{\code{strand(x)}, \code{strand(x) <- value}:}{
      Get or set the strand for each alignment in \code{x} (see Details
      section above for more information about the strand of an alignment).
      \code{value} can be a factor (with levels +, - and *), or a 'factor'
      \link[S4Vectors]{Rle}, or a character vector.
    }
    \item{\code{cigar(x)}:}{
      Returns a character vector of length \code{length(x)}
      containing the CIGAR string for each alignment.
    }
    \item{\code{qwidth(x)}:}{
      Returns an integer vector of length \code{length(x)}
      containing the length of the query *after* hard clipping
      (i.e. the length of the query sequence that is stored in
      the corresponding SAM/BAM record).
    }
    \item{\code{start(x)}, \code{end(x)}:}{
      Returns an integer vector of length \code{length(x)}
      containing the "start" and "end" (respectively) of the query
      for each alignment. See Details section above for the exact
      definitions of the "start" and "end" of a query.
      Note that \code{start(x)} and \code{end(x)} are equivalent
      to \code{start(granges(x))} and \code{end(granges(x))},
      respectively (or, alternatively, to \code{min(rglist(x))} and
      \code{max(rglist(x))}, respectively).
    }
    \item{\code{width(x)}:}{
      Equivalent to \code{width(granges(x))} (or, alternatively, to
      \code{end(x) - start(x) + 1L}).
      Note that this is generally different from \code{qwidth(x)}
      except for alignments with a trivial CIGAR string (i.e. a
      string of the form \code{"<n>M"} where <n> is a number).
    }
    \item{\code{njunc(x)}:}{
      Returns an integer vector of the same length as \code{x} containing
      the number of junctions (i.e. N operations in the CIGAR) in each
      alignment. Equivalent to \code{unname(elementNROWS(rglist(x))) - 1L}.
    }
    \item{\code{seqinfo(x)}, \code{seqinfo(x) <- value}:}{
      Get or set the information about the underlying sequences.
      \code{value} must be a \link[GenomeInfoDb]{Seqinfo} object.
    }
    \item{\code{seqlevels(x)}, \code{seqlevels(x) <- value}:}{
      Get or set the sequence levels.
      \code{seqlevels(x)} is equivalent to \code{seqlevels(seqinfo(x))}
      or to \code{levels(seqnames(x))}, those 2 expressions being
      guaranteed to return identical character vectors on a GAlignments
      object. \code{value} must be a character vector with no NAs.
      See \code{?\link{seqlevels}} for more information.
    }
    \item{\code{seqlengths(x)}, \code{seqlengths(x) <- value}:}{
      Get or set the sequence lengths.
      \code{seqlengths(x)} is equivalent to \code{seqlengths(seqinfo(x))}.
      \code{value} can be a named non-negative integer or numeric vector
      eventually with NAs.
    }
    \item{\code{isCircular(x)}, \code{isCircular(x) <- value}:}{
      Get or set the circularity flags.
      \code{isCircular(x)} is equivalent to \code{isCircular(seqinfo(x))}.
      \code{value} must be a named logical vector eventually with NAs.
    }
    \item{\code{genome(x)}, \code{genome(x) <- value}:}{
      Get or set the genome identifier or assembly name for each sequence.
      \code{genome(x)} is equivalent to \code{genome(seqinfo(x))}.
      \code{value} must be a named character vector eventually with NAs.
    }
    \item{\code{seqnameStyle(x)}:}{
      Get or set the seqname style for \code{x}.
      Note that this information is not stored in \code{x} but inferred
      by looking up \code{seqnames(x)} against a seqname style database
      stored in the \pkg{seqnames.db} metadata package (required).
      \code{seqnameStyle(x)} is equivalent to \code{seqnameStyle(seqinfo(x))}
      and can return more than 1 seqname style (with a warning)
      in case the style cannot be determined unambiguously.
    }
  }
}

\section{Coercion}{
  In the code snippets below, \code{x} is a GAlignments object.

  \describe{
    \item{\code{granges(x, use.names=TRUE, use.mcols=FALSE)},
          \code{ranges(x, use.names=TRUE, use.mcols=FALSE)}:}{
      Return a \link{GRanges} object (for \code{granges()}) or
      \link[IRanges]{IRanges}) object (for \code{ranges()}) \emph{parallel}
      to \code{x} where the i-th element is the range of the genomic region
      spanned by the i-th alignment in \code{x}. All gaps in the region are
      ignored.

      If \code{use.names} is TRUE, then the names on \code{x}
      (if any) are propagated to the returned object.
      If \code{use.mcols} is TRUE, then the metadata columns on \code{x}
      (if any) are propagated to the returned object.
    }
    \item{\code{grglist(x, use.names=TRUE, use.mcols=FALSE,
                        order.as.in.query=FALSE, drop.D.ranges=FALSE)},
          \code{rglist(x, use.names=TRUE, use.mcols=FALSE,
                       order.as.in.query=FALSE, drop.D.ranges=FALSE)}:}{
      Return either a \link{GRangesList} or a \link[IRanges]{IntegerRangesList}
      object of length \code{length(x)} where the i-th element represents
      the ranges (with respect to the reference) of the i-th alignment in
      \code{x}.

      More precisely, the \link[IRanges]{IntegerRangesList} object returned
      by \code{rglist(x)} is a \link[IRanges]{CompressedIRangesList} object.

      If \code{use.names} is TRUE, then the names on \code{x}
      (if any) are propagated to the returned object.
      If \code{use.mcols} is TRUE, then the metadata columns on \code{x}
      (if any) are propagated to the returned object.

      The \code{order.as.in.query} toggle affects the order of the ranges
      \emph{within} each top-level element of the returned object.

      If FALSE (the default), then the ranges are ordered from 5' to 3'
      in elements associated with the plus strand (i.e. corresponding to
      alignments located on the plus strand), and from 3' to 5' in elements
      associated with the minus strand. So, whatever the strand is, the ranges
      are in ascending order (i.e. left-to-right).

      If TRUE, then the order of the ranges in elements associated
      with the \emph{minus} strand is reversed. So they end up being
      ordered from 5' to 3' too, which means that they are now in decending
      order (i.e. right-to-left). It also means that, when
      \code{order.as.in.query=TRUE} is used, the ranges are
      \emph{always} ordered consistently with the original "query template",
      that is, in the order defined by walking the "query template" from the
      beginning to the end.

      If \code{drop.D.ranges} is TRUE, then deletions (D operations
      in the CIGAR) are treated like junctions (N operations in the CIGAR),
      that is, the ranges corresponding to deletions are dropped.

      See Details section above for more information.
    }
    \item{\code{as(x, "GRanges")}, \code{as(x, "IntegerRanges")},
      \code{as(x, "GRangesList")}, \code{as(x, "IntegerRangesList")}:}{
      Alternate ways of doing
      \code{granges(x, use.names=TRUE, use.mcols=TRUE)},
      \code{ranges(x, use.names=TRUE, use.mcols=TRUE)},
      \code{grglist(x, use.names=TRUE, use.mcols=TRUE)}, and
      \code{rglist(x, use.names=TRUE, use.mcols=TRUE)}, respectively.
    }
  }

  In the code snippet below, \code{x} is a \link[GenomicRanges]{GRanges}
  object.

  \describe{
    \item{\code{as(from, "GAlignments")}:}{
      Creates a GAlignments object from a \link[GenomicRanges]{GRanges} object.
      The metadata columns are propagated. cigar values are created from the
      sequence width unless a "cigar" metadata column already exists in
      \code{from}.
    }
  }
}

\section{Subsetting and related operations}{
  In the code snippets below, \code{x} is a GAlignments object.

  \describe{
    \item{\code{x[i]}:}{
      Return a new GAlignments object made of the selected
      alignments. \code{i} can be a numeric or logical vector.
    }
  }
}

\section{Concatenation}{
  \describe{
    \item{\code{c(x, ..., ignore.mcols=FALSE)}:}{
      Concatenate GAlignments object \code{x} and the GAlignments objects in
      \code{...} together.
      See \code{?\link[S4Vectors]{c}} in the \pkg{S4Vectors} package for
      more information about concatenating Vector derivatives.
    }
  }
}

\section{Other methods}{

  \describe{
    \item{\code{show(x)}:}{
      By default the \code{show} method displays 5 head and 5 tail
      elements. This can be changed by setting the global options
      \code{showHeadLines} and \code{showTailLines}. If the object
      length is less than (or equal to) the sum of these 2 options
      plus 1, then the full object is displayed.
      Note that these options also affect the display of \link{GRanges}
      and \link{GAlignmentPairs} objects, as well as other objects
      defined in the \pkg{IRanges} and \pkg{Biostrings} packages
      (e.g. \link[IRanges]{IntegerRanges} and \link[Biostrings]{DNAStringSet}
      objects).
    }
  }
}

\references{
  \url{http://samtools.sourceforge.net/}
}

\author{Hervé Pagès and P. Aboyoun}

\seealso{
  \itemize{
    \item \code{\link{readGAlignments}} for reading genomic alignments
          from a file (typically a BAM file) into a GAlignments object.

    \item \link{GAlignmentPairs} objects for handling aligned paired-end
          reads.

    \item \link{junctions-methods} for extracting and summarizing junctions
          from a GAlignments object.

    \item \link[GenomicAlignments]{coverage-methods} for computing the
          coverage of a GAlignments object.

    \item \link[GenomicAlignments]{findOverlaps-methods} for finding
          overlapping genomic alignments.

    \item \code{\link[GenomeInfoDb]{seqinfo}} in the \pkg{GenomeInfoDb}
          package for getting/setting/modifying the sequence information
          stored in an object.

    \item The \link[GenomicRanges]{GRanges} and
          \link[GenomicRanges]{GRangesList} classes defined and documented
          in the \pkg{GenomicRanges} package.

    \item The \link[IRanges]{CompressedIRangesList} class defined and
          documented in the \pkg{IRanges} package.
  }
}

\examples{
library(Rsamtools)  # for the ex1.bam file
ex1_file <- system.file("extdata", "ex1.bam", package="Rsamtools")
gal <- readGAlignments(ex1_file, param=ScanBamParam(what="flag"))
gal

## ---------------------------------------------------------------------
## A. BASIC MANIPULATION
## ---------------------------------------------------------------------
length(gal)
head(gal)
names(gal)  # no names by default
seqnames(gal)
strand(gal)
head(cigar(gal))
head(qwidth(gal))
table(qwidth(gal))
head(start(gal))
head(end(gal))
head(width(gal))
head(njunc(gal))
seqlevels(gal)

## Invert the strand:
invertStrand(gal)

## Rename the reference sequences:
seqlevels(gal) <- sub("seq", "chr", seqlevels(gal))
seqlevels(gal)

grglist(gal)  # a GRangesList object
stopifnot(identical(unname(elementNROWS(grglist(gal))), njunc(gal) + 1L))
granges(gal)  # a GRanges object
rglist(gal)   # a CompressedIRangesList object
stopifnot(identical(unname(elementNROWS(rglist(gal))), njunc(gal) + 1L))
ranges(gal)   # an IRanges object

## Modify the number of lines in 'show'
options(showHeadLines=3)
options(showTailLines=2)
gal

## Revert to default
options(showHeadLines=NULL)
options(showTailLines=NULL)

## ---------------------------------------------------------------------
## B. SUBSETTING
## ---------------------------------------------------------------------
gal[strand(gal) == "-"]
gal[grep("I", cigar(gal), fixed=TRUE)]
gal[grep("N", cigar(gal), fixed=TRUE)]  # no junctions

## A confirmation that none of the alignments contains junctions (in
## other words, each alignment can be represented by a single genomic
## range on the reference):
stopifnot(all(njunc(gal) == 0))

## Different ways to subset:
gal[6]             # a GAlignments object of length 1
grglist(gal)[[6]]  # a GRanges object of length 1
rglist(gal)[[6]]   # a NormalIRanges object of length 1

## Unlike N operations, D operations don't introduce gaps:
ii <- grep("D", cigar(gal), fixed=TRUE)
gal[ii]
njunc(gal[ii])
grglist(gal[ii])

## qwidth() vs width():
gal[qwidth(gal) != width(gal)]

## This MUST return an empty object:
gal[cigar(gal) == "35M" & qwidth(gal) != 35]
## but this doesn't have too:
gal[cigar(gal) != "35M" & qwidth(gal) == 35]
}

\keyword{methods}
\keyword{classes}
