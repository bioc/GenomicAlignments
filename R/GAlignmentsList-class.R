### =========================================================================
### GAlignmentsList objects
### -------------------------------------------------------------------------
###

setClass("GAlignmentsList",
    contains="CompressedRangesList",
    representation(
        unlistData="GAlignments",
        elementMetadata="DataFrame"
    ),
    prototype(
        elementType="GAlignments",
        elementMetadata=new("DFrame")
    )
)

### Formal API:
###   names(x)    - NULL or character vector.
###   length(x)   - single integer. Nb of alignments in 'x'.
###   seqnames(x) - 'factor' Rle of the same length as 'x'.
###   rname(x)    - same as 'seqnames(x)'.
###   seqnames(x) <- value - replacement form of 'seqnames(x)'.
###   rname(x) <- value - same as 'seqnames(x) <- value'.
###   cigar(x)    - character vector of the same length as 'x'.
###   strand(x)   - 'factor' Rle of the same length as 'x' (levels: +, -, *).
###   qwidth(x)   - integer vector of the same length as 'x'.
###   start(x), end(x), width(x) - integer vectors of the same length as 'x'.
###   njunc(x)    - integer vector of the same length as 'x'.

###   grglist(x)  - GRangesList object of the same length as 'x'.
###   granges(x)  - GRanges object of the same length as 'x'.
###   rglist(x)   - CompressedIRangesList object of the same length as 'x'.
###   ranges(x)   - IRanges object of the same length as 'x'.

###   show(x)     - compact display in a data.frame-like fashion.
###   GAlignmentsList(x, ...) - constructor.
###   x[i]        - GAlignmentsList object of the same class as 'x'
###                 (endomorphism).
###
###   findOverlaps(query, subject) - 'query' or 'subject' or both are
###                 GAlignments objects. Just a convenient wrapper for
###                 'findOverlaps(grglist(query), subject, ...)', etc...
###
###   countOverlaps(query, subject) - 'query' or 'subject' or both are
###                 GAlignments objects. Just a convenient wrapper for
###                 'countOverlaps(grglist(query), subject, ...)', etc...
###
###   subsetByOverlaps(query, subject) - 'query' or 'subject' or both are
###                 GAlignments objects.
###

###   qnarrow(x, start=NA, end=NA, width=NA) - GAlignmentsList object of the
###                 same length and class as 'x' (endomorphism).
###
###   narrow(x, start=NA, end=NA, width=NA) - GAlignmentsList object of the
###                 same length and class as 'x' (endomorphism).
###

### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Getters.
###

setMethod("seqnames", "GAlignmentsList", 
    function(x) relist(seqnames(unlist(x, use.names=FALSE)), x)
)

setMethod("rname", "GAlignmentsList", 
    function(x) relist(rname(unlist(x, use.names=FALSE)), x)
)

setMethod("cigar", "GAlignmentsList", 
    function(x) relist(cigar(unlist(x, use.names=FALSE)), x)
)

setMethod("strand", "GAlignmentsList",
    function(x) relist(strand(unlist(x, use.names=FALSE)), x)
)

setMethod("qwidth", "GAlignmentsList",
    function(x) relist(qwidth(unlist(x, use.names=FALSE)), x)
)

setMethod("njunc", "GAlignmentsList",
    function(x) relist(njunc(unlist(x, use.names=FALSE)), x)
)

setMethod("seqinfo", "GAlignmentsList",
    function(x) seqinfo(unlist(x, use.names=FALSE))
)

setMethod("elementMetadata", "GAlignmentsList",
    GenomicRanges:::get_GenomicRangesList_mcols
)


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Setters.
###

setReplaceMethod("rname", "GAlignmentsList",
    function(x, value) `seqnames<-`(x, value)
)

setReplaceMethod("elementMetadata", "GAlignmentsList", 
    GenomicRanges:::set_CompressedGenomicRangesList_mcols
)

setReplaceMethod("strand", "GAlignmentsList",
    GenomicRanges:::set_CompressedGenomicRangesList_strand
)
setReplaceMethod("strand", c("GAlignmentsList", "character"), 
    function(x, ..., value)
    {
        if (length(value) > 1L)
            stop("length(value) must be 1")
        strand(x@unlistData) <- value
        x
    }
)

setReplaceMethod("seqinfo", "GAlignmentsList",
    GenomicRanges:::set_CompressedGenomicRangesList_seqinfo
)

setReplaceMethod("seqnames", "GAlignmentsList",
    GenomicRanges:::set_CompressedGenomicRangesList_seqnames
)


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Validity.
###

.valid.GAlignmentsList <- function(x)
{
   ## TDB: Currently known pitfalls are caught by
   ## GAlignments validity. 
}

setValidity2("GAlignmentsList", .valid.GAlignmentsList)


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Constructors.
###

GAlignmentsList <- function(...)
{
    listData <- list(...)
    if (length(listData) == 0L) {
        unlistData <- GAlignments()
    } else {
        if (length(listData) == 1L && is.list(listData[[1L]]))
            listData <- listData[[1L]]
        if (!all(sapply(listData, is, "GAlignments")))
            stop("all elements in '...' must be GAlignments objects")
        unlistData <- suppressWarnings(do.call("c", unname(listData)))
    }
    relist(unlistData, PartitioningByEnd(listData))
}


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Coercion.
###

setMethod("ranges", "GAlignmentsList",
    function(x, use.names=TRUE, use.mcols=FALSE)
    {
        if (!isTRUEorFALSE(use.names))
            stop("'use.names' must be TRUE or FALSE")
        if (!isTRUEorFALSE(use.mcols))
            stop("'use.mcols' must be TRUE or FALSE")
        ans <- unlist(range(rglist(x)), use.names=FALSE)
        if (use.names)
            names(ans) <- names(x)
        if (use.mcols)
            mcols(ans) <- mcols(x, use.names=FALSE)
        ans
    }
)

setMethod("granges", "GAlignmentsList",
    function(x, use.names=TRUE, use.mcols=FALSE, ignore.strand=FALSE) 
    {
        if (!isTRUEorFALSE(use.mcols))
            stop("'use.mcols' must be TRUE or FALSE")
        if (ignore.strand)
            strand(x@unlistData) <- "*"
        msg <- paste0("For some list elements in 'x', the ranges are ",
                      "not on the same chromosome and strand. ",
                      "Cannot extract a single range for them. ",
                      "As a consequence, the returned GRanges object ",
                      "is not parallel to 'x'.")
        rg <- range(grglist(x, ignore.strand=ignore.strand))
        is_one_to_one <- all(elementNROWS(rg) == 1L)
        if (!is_one_to_one && all(width(x@partitioning) > 0)) {
            if (ignore.strand)
                warning(msg)
            else
                warning(paste0(msg, " Consider using 'ignore.strand=TRUE'."))
        }
        ans <- unlist(rg, use.names=use.names)
        if (is_one_to_one && use.mcols)
            mcols(ans) <- mcols(x, use.names=FALSE)
        ans
    }
)

setMethod("grglist", "GAlignmentsList",
    function(x, use.names=TRUE, use.mcols=FALSE, drop.D.ranges=FALSE,
                ignore.strand=FALSE) 
    {
        if (!isTRUEorFALSE(use.names))
            stop("'use.names' must be TRUE or FALSE")
        if (!isTRUEorFALSE(use.mcols))
            stop("'use.mcols' must be TRUE or FALSE")
        if (!isTRUEorFALSE(ignore.strand))
            stop("'ignore.strand' must be TRUE or FALSE")
        if (ignore.strand)
            strand(x@unlistData) <- "*"
        unlisted_x <- unlist(x, use.names=FALSE)
        grl <- grglist(unlisted_x, drop.D.ranges=drop.D.ranges)
        ans <- IRanges:::regroupBySupergroup(grl, x)
        if (!use.names)
            names(ans) <- NULL
        if (use.mcols)
            mcols(ans) <- mcols(x, use.names=FALSE)
        ans
    }
)
 
setMethod("rglist", "GAlignmentsList",
    function(x, use.names=TRUE, use.mcols=FALSE, drop.D.ranges=FALSE)
    {
        if (!isTRUEorFALSE(use.names))
            stop("'use.names' must be TRUE or FALSE")
        if (!isTRUEorFALSE(use.mcols))
            stop("'use.mcols' must be TRUE or FALSE")
        unlisted_x <- unlist(x, use.names=FALSE)
        rgl <- rglist(unlisted_x, drop.D.ranges=drop.D.ranges)
        ans <- IRanges:::regroupBySupergroup(rgl, x)
        if (!use.names)
            names(ans) <- NULL
        if (use.mcols)
            mcols(ans) <- mcols(x, use.names=FALSE)
        ans
    }
)

setAs("GAlignmentsList", "IntegerRanges", 
    function(from) ranges(from, use.names=TRUE, use.mcols=TRUE)
)
setAs("GAlignmentsList", "GRanges", 
    function(from) granges(from, use.names=TRUE, use.mcols=TRUE)
)
setAs("GAlignmentsList", "GRangesList", 
    function(from) grglist(from, use.names=TRUE, use.mcols=TRUE)
)
setAs("GAlignmentsList", "IntegerRangesList", 
    function(from) rglist(from, use.names=TRUE, use.mcols=TRUE)
)

setAs("GAlignmentPairs", "GAlignmentsList", 
    function(from) 
    {
        if (length(from) == 0L)
            pbe <- PartitioningByEnd()
        else
            pbe <- PartitioningByEnd(seq(2, 2*length(from), 2), names=names(from)) 
        new("GAlignmentsList",
            unlistData=unlist(from, use.names=FALSE),
            partitioning=pbe)
        }
)

setAs("GAlignmentsList", "GAlignmentPairs",
    function(from)
    {
        from_mcols <- mcols(from, use.names=FALSE)
        ga <- unlist(from[from_mcols$mate_status != "unmated"])
        first <- c(TRUE, FALSE)
        last <- c(FALSE, TRUE)
        ga_mcols <- mcols(ga, use.names=FALSE)
        isProperPair <- if (!is.null(ga_mcols$flag)) {
            bamFlagTest(ga_mcols$flag[first], "isProperPair")
        } else {
            TRUE
        }
        GAlignmentPairs(ga[first], ga[last],
                        isProperPair=isProperPair,
                        names=names(ga)[first])
    }
)

setAs("list", "GAlignmentsList", function(from) do.call(GAlignmentsList, from))


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Subsetting.
###

## "[", "[<-" and "[[", "[[<-" from CompressedList


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Going from GAlignments to GAlignmentsList with extractList() and family.
###

setMethod("relistToClass", "GAlignments",
    function(x) "GAlignmentsList"
)


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### show method.
###

setMethod("show", "GAlignmentsList",
    function(object)
        GenomicRanges:::show_GenomicRangesList(object)
)

