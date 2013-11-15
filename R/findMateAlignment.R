### =========================================================================
### findMateAlignment()
### -------------------------------------------------------------------------
###
### For each element in GAlignments object 'x', finds its mate in GAlignments
### object 'y'.
###
### Alignments 'x[i1]' and 'y[i2]' are considered mates iff they pass all the
### following tests:
###
###   (A) names(x[i1]) == names(y[i2])
###
###   (B) mcols(x[i1])$mrnm == seqnames(y[i2]) &
###       mcols(y[i2])$mrnm == seqnames(x[i1])
###
###   (C) mcols(x[i1])$mpos == start(y[i2]) &
###       mcols(y[i2])$mpos == start(x[i1])
###
###   (D) isMateMinusStrand(x[i1]) == isMinusStrand(y[i2]) &
###       isMateMinusStrand(y[i2]) == isMinusStrand(x[i1])
###
###   (E) isFirstSegment(x[i1]) & isLastSegment(y[i2]) |
###       isFirstSegment(y[i2]) & isLastSegment(x[i1])
###
###   (F) isProperPair(x[i1]) == isProperPair(y[i2])
###
###   (G) isNotPrimaryRead(x[i1]) == isNotPrimaryRead(y[i2])

.checkMetadatacols <- function(arg, argname)
{
    if (!is(arg, "GAlignments"))
        stop("'", argname, "' must be a GAlignments object")
    if (is.null(names(arg)))
        stop("'", argname, "' must have names")
    arg_mcols <- mcols(arg)
    REQUIRED_COLNAMES <- c("flag", "mrnm", "mpos")
    if (!all(REQUIRED_COLNAMES %in% colnames(arg_mcols))) {
        colnames_in1string <-
            paste0("\"", REQUIRED_COLNAMES, "\"", collapse=", ")
        stop("required columns in 'mcols(", argname, ")': ",
             colnames_in1string)
    }
    if (!is.integer(arg_mcols$flag))
        stop("'mcols(", argname, ")$flag' must be an integer vector")
    if (!is.factor(arg_mcols$mrnm))
        stop("'mcols(", argname, ")$mrnm' must be a factor")
    if (!identical(levels(arg_mcols$mrnm), levels(seqnames(arg))))
        stop("'mcols(", argname, ")$mrnm' and 'seqnames(", argname, ")' ",
             "must have exactly the same levels in the same order")
    if (!is.integer(arg_mcols$mpos))
        stop("'mcols(", argname, ")$mpos' must be an integer vector")
    arg_mcols
}

### 'names', 'flagbits', 'mrnm', and 'mpos', must all come from the same
###     GAlignments object x.
### 'names': names(x).
### 'flagbits': integer matrix (of 0's and 1's) obtained with
###     bamFlagAsBitMatrix(mcols(x)$flag, bitnames=.MATING_FLAG_BITNAMES)
### 'mrnm': factor obtained with mcols(x)$mrnm
### 'mpos': integer vector obtained with mcols(x)$mpos
### Returns 'names' with NAs injected at positions corresponding to alignments
### that satisfy at least one of following conditions:
###     1. Bit 0x1 (isPaired) is 0
###     2. Read is neither first or last mate
###     3. Bit 0x8 (hasUnmappedMate) is 1
###     4. 'mrnm' is NA (i.e. RNEXT = '*')
###     5. 'mpos' is NA (i.e. PNEXT = 0)
### My understanding of the SAM Spec is that 3., 4. and 5. should happen
### simultaneously even though the Spec don't clearly state this.

.MATING_FLAG_BITNAMES <- c("isPaired", "hasUnmappedMate",
                           "isFirstMateRead", "isSecondMateRead")

.makeGAlignmentsGNames <- function(names, flagbits, mrnm, mpos)
{
    is_paired <- flagbits[ , "isPaired"]
    is_first <- flagbits[ , "isFirstMateRead"]
    is_last <- flagbits[ , "isSecondMateRead"]
    has_unmappedmate <- flagbits[ , "hasUnmappedMate"]
    alter_idx <- which(!is_paired |
                       is_first == is_last |
                       has_unmappedmate |
                       is.na(mrnm) |
                       is.na(mpos))
    names[alter_idx] <- NA_integer_
    names
}

### Puts NAs last.
.getCharacterOrderAndGroupSizes <- function(x)
{
    x2 <- match(x, x,
                nomatch=.Machine$integer.max,
                incomparables=NA_character_)
    xo <- IRanges:::orderInteger(x2)
    ox2 <- Rle(x2[xo])
    group.sizes <- runLength(ox2)
    ngroup <- length(group.sizes)
    if (ngroup != 0L && runValue(ox2)[ngroup] == .Machine$integer.max)
        group.sizes <- group.sizes[-ngroup]
    list(xo=xo, group.sizes=group.sizes)
}

### Should return the same as:
###   args <- as.list(setNames(rep(TRUE, length(bitnames)), bitnames))
###   tmp <- do.call(scanBamFlag, args)
###   tmp[[2L]] - tmp[[1L]]
.makeFlagBitmask <- function(bitnames)
{
    bitpos <- match(bitnames, FLAG_BITNAMES)
    sum(as.integer(2L ^ (bitpos-1L)))
}

### 3 equivalent implementations for this:
###   (a) x %in% x[duplicated(x)]
###   (b) duplicated(x) | duplicated(x, fromLast=TRUE)
###   (c) xx <- match(x, x); ans <- xx != seq_along(xx); ans[xx] <- ans; ans
### Comparing the 3 implementations on an integer vector of length 12 millions:
###   (a) is the most memory efficient;
###   (b) is a little bit faster than (a) (by only 8%) but uses between 12-14%
###       more memory;
###   (c) is as fast as (a) but uses about 30% more memory.
.hasDuplicates <- function(x)
{
    x %in% x[duplicated(x)]
}

### 'x_hits' and 'y_hits' must be 2 integer vectors of the same length N
### representing the N edges of a bipartite graph between the [1, x_len] and
### [1, y_len] intervals (the i-th edge being represented by (x[i], y[i])).
### Returns an integer vector F of length 'x_len' where F[k] is defined by:
###   - If there is no occurence of k in 'x', then F[k] = NA.
###   - If there is more than 1 occurence of k in 'x', then F[k] = 0.
###   - If there is exactly 1 occurence of k in 'x', at index i_k, then
###     F[k] = y[i_k].
### In addition, if more than 1 value of index k is associated to F[k], then
### F[k] is replaced by -F[k].
.makeMateIdx2 <- function(x_hits, y_hits, x_len)
{
    idx1 <- which(.hasDuplicates(y_hits))
    y_hits[idx1] <- - y_hits[idx1]
    idx2 <- which(.hasDuplicates(x_hits))
    y_hits[idx2] <- 0L
    ans <- rep.int(NA_integer_, x_len)
    ans[x_hits] <- y_hits
    ans
}

.showGAlignmentsEltsWithMoreThan1Mate <- function(x, idx)
{
    if (length(idx) == 0L)
        return()
    cat("\n!! Found more than 1 mate for the following elements in 'x': ",
        paste(idx, collapse=", "),
        ".\n!! Details:\n!! ", sep="")
    GenomicRanges:::showGAlignments(x[idx],
                                         margin="!! ",
                                         with.classinfo=TRUE,
                                         print.seqlengths=FALSE)
    cat("!! ==> won't assign a mate to them!\n")
}

.dump_envir <- new.env(hash=TRUE, parent=emptyenv())
.dumpEnvir <- function() .dump_envir

flushDumpedAlignments <- function()
{
    objnames <- ls(envir=.dumpEnvir())
    rm(list=objnames, envir=.dumpEnvir())
}

.dumpAlignments <- function(x, idx)
{
    objnames <- ls(envir=.dumpEnvir())
    nobj <- length(objnames)
    if (nobj == 0L) {
        new_objname <- 1L
    } else {
        new_objname <- as.integer(objnames[nobj]) + 1L
    }
    new_objname <- sprintf("%08d", new_objname)
    assign(new_objname, x[idx], envir=.dumpEnvir())
}

countDumpedAlignments <- function()
{
    sum(unlist(eapply(.dumpEnvir(), length, USE.NAMES=FALSE)))
}

getDumpedAlignments <- function()
{
    objnames <- ls(envir=.dumpEnvir())
    args <- unname(mget(objnames, envir=.dumpEnvir()))
    do.call(c, args)
}

### Takes about 2.3 s and 170MB of RAM to mate 1 million alignments,
### and about 13 s and 909MB of RAM to mate 5 million alignments.
### So it's a little bit faster and more memory efficient than
### findMateAlignment2().
findMateAlignment <- function(x)
{
    x_names <- names(x)
    if (is.null(x_names))
        stop("'x' must have names")
    x_mcols <- .checkMetadatacols(x, "x")
    ## flushDumpedAlignments() must be placed *after* the first reference to
    ## 'x', otherwise, when doing 'findMateAlignment(getDumpedAlignments())',
    ## the flushing would happen before 'x' is evaluated, causing 'x' to be
    ## evaluated to NULL.
    flushDumpedAlignments()
    x_flag <- x_mcols$flag
    bitnames <- c(.MATING_FLAG_BITNAMES, "isMinusStrand", "isMateMinusStrand")
    x_flagbits <- bamFlagAsBitMatrix(x_flag, bitnames=bitnames)
    x_mrnm <- x_mcols$mrnm
    x_mpos <- x_mcols$mpos
    x_gnames <- .makeGAlignmentsGNames(x_names, x_flagbits, x_mrnm, x_mpos)
    x_seqnames <- as.factor(seqnames(x))
    x_start <- start(x)

    xo_and_GS <- .getCharacterOrderAndGroupSizes(x_gnames)
    xo <- xo_and_GS$xo
    group.sizes <- xo_and_GS$group.sizes
    ans <- Rsamtools:::.findMateWithinGroups(group.sizes,
                           x_flag[xo], x_seqnames[xo],
                           x_start[xo], x_mrnm[xo], x_mpos[xo])
    dumpme_idx <- which(ans <= 0L)
    if (length(dumpme_idx) != 0L) {
        .dumpAlignments(x, xo[dumpme_idx])
        ans[dumpme_idx] <- NA_integer_
    }
    ans[xo] <- xo[ans]  # isn't that cute!
    dump_count <- countDumpedAlignments()
    if (dump_count != 0L)
        warning("  ", dump_count, " alignments with ambiguous pairing ",
                "were dumped.\n    Use 'getDumpedAlignments()' to retrieve ",
                "them from the dump environment.")
    ans
}


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### findMateAlignment2().
###

### .findMatches() is the same as match() except that it returns *all*
### the matches (in a Hits object, ordered by queryHits first, then by
### subjectHits).
### TODO: Make findMatches() an S4 generic function with at least a method for
### vectors. Like findOverlaps(), findMatches() could support the 'select' arg
### (but with supported values "all", "first" and "last" only, no need for
### "arbitrary") so that when used with 'select="first"', it would be
### equivalent to match(). This stuff would go in IRanges.
.findMatches <- function(query, subject, incomparables=NULL)
{
    if (!is.vector(query) || !is.vector(subject))
        stop("'query' and 'subject' must be vectors")
    if (class(query) != class(subject))
        stop("'query' and 'subject' must be vectors of the same class")
    if (!is.null(incomparables) && !(is.vector(incomparables) &&
                                     class(incomparables) == class(query)))
        stop("'incomparables' must be NULL or a vector ",
             "of the same class as 'query' and 'subject'")
    m0 <- match(query, subject, incomparables=incomparables)
    query_hits0 <- which(!is.na(m0))
    if (length(query_hits0) == 0L) {
        query_hits <- subject_hits <- integer(0)
    } else {
        subject_hits0 <- m0[query_hits0]
        subject_low2high <- IRanges:::.makeLow2highFromHigh2low(
                                high2low(subject))
        extra_hits <- subject_low2high[subject_hits0]
        query_nhits <- 1L + elementLengths(extra_hits)
        query_hits <- rep.int(query_hits0, query_nhits)
        subject_hits <- integer(length(query_hits))
        idx0 <- cumsum(c(1L, query_nhits[-length(query_nhits)]))
        subject_hits[idx0] <- m0[query_hits0]
        subject_hits[-idx0] <- unlist(extra_hits,
                                      recursive=FALSE, use.names=FALSE)
    }
    new2("Hits", queryHits=query_hits, subjectHits=subject_hits,
                 queryLength=length(query), subjectLength=length(subject),
                 check=FALSE)
}

### Use to find self matches in 'x'. Twice faster than
### 'findMatches(x, x, incomparables=NA_character_)' and uses
### twice less memory.
.findSelfMatches.character <- function(x)
{
    xo_and_GS <- .getCharacterOrderAndGroupSizes(x)
    xo <- xo_and_GS$xo
    GS <- xo_and_GS$group.sizes
    ans <- IRanges:::makeAllGroupInnerHits(GS, hit.type=1L)
    ans@queryHits <- xo[ans@queryHits]
    ans@subjectHits <- xo[ans@subjectHits]
    ans@queryLength <- ans@subjectLength <- length(x)
    ans
}

### Takes about 2.8 s and 196MB of RAM to mate 1 million alignments,
### and about 19 s and 1754MB of RAM to mate 5 million alignments.
findMateAlignment2 <- function(x, y=NULL)
{
    x_names <- names(x)
    if (is.null(x_names))
        stop("'x' must have names")
    x_mcols <- .checkMetadatacols(x, "x")
    x_seqnames <- as.factor(seqnames(x))
    x_start <- start(x)
    x_mrnm <- x_mcols$mrnm
    x_mpos <- x_mcols$mpos
    x_flag <- x_mcols$flag
    bitnames <- c(.MATING_FLAG_BITNAMES, "isMinusStrand", "isMateMinusStrand")
    x_flagbits <- bamFlagAsBitMatrix(x_flag, bitnames=bitnames)
    x_gnames <- .makeGAlignmentsGNames(x_names, x_flagbits, x_mrnm, x_mpos)

    if (is.null(y)) {
        y_seqnames <- x_seqnames
        y_start <- x_start
        y_mrnm <- x_mrnm
        y_mpos <- x_mpos
        y_flag <- x_flag

        hits <- .findSelfMatches.character(x_gnames)
    } else {
        y_names <- names(y)
        if (is.null(y_names))
            stop("'y' must have names")
        y_mcols <- .checkMetadatacols(y, "y")
        y_seqnames <- as.factor(seqnames(y))
        y_start <- start(y)
        y_mrnm <- y_mcols$mrnm
        y_mpos <- y_mcols$mpos
        y_flag <- y_mcols$flag
        y_flagbits <- bamFlagAsBitMatrix(y_flag, bitnames=bitnames)
        y_gnames <- .makeGAlignmentsGNames(y_names, y_flagbits, y_mrnm, y_mpos)

        hits <- .findMatches(x_gnames, y_gnames, incomparables=NA_character_)
    }

    x_hits <- queryHits(hits)
    y_hits <- subjectHits(hits)
    valid_hits <- Rsamtools:::.isValidHit(
                              x_flag[x_hits], x_seqnames[x_hits],
                              x_start[x_hits], x_mrnm[x_hits], x_mpos[x_hits],
                              y_flag[y_hits], y_seqnames[y_hits],
                              y_start[y_hits], y_mrnm[y_hits], y_mpos[y_hits])
    x_hits <- x_hits[valid_hits]
    y_hits <- y_hits[valid_hits]

    if (is.null(y)) {
        tmp <- x_hits
        x_hits <- c(x_hits, y_hits)
        y_hits <- c(y_hits, tmp)
    }
    ans <- .makeMateIdx2(x_hits, y_hits, length(x))
    if (any(ans <= 0L, na.rm=TRUE)) {
        more_than_1_mate_idx <- which(ans == 0L)
        .showGAlignmentsEltsWithMoreThan1Mate(x, more_than_1_mate_idx)
        ans[ans <= 0L] <- NA_integer_
    }
    ans
}


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### makeGAlignmentPairs().
###

### TODO: Make isFirstSegment() an S4 generic function with methods for
### matrices, integer vectors, and GAlignments objects. Put this with the
### flag utils in Rsamtools.
.isFirstSegment.matrix <- function(x)
{
    is_paired <- as.logical(x[ , "isPaired"])
    is_first0 <- as.logical(x[ , "isFirstMateRead"])
    is_last0 <- as.logical(x[ , "isSecondMateRead"])
    ## According to SAM Spec, bits 0x40 (isFirstMateRead) and 0x80
    ## (isSecondMateRead) can both be set or unset, even when bit 0x1
    ## (isPaired) is set. However we are not interested in those situations
    ## (which have a special meaning).
    is_paired & is_first0 & (!is_last0)
}

.isFirstSegment.integer <- function(flag)
{
    bitnames <- c("isPaired", "isFirstMateRead", "isSecondMateRead")
    .isFirstSegment.matrix(bamFlagAsBitMatrix(flag, bitnames=bitnames))
}

.isFirstSegment.GAlignments <- function(x)
    .isFirstSegment.integer(mcols(x)$flag)

### TODO: Make isLastSegment() an S4 generic function with methods for
### matrices, integer vectors, and GAlignments objects. Put this with the
### flag utils in Rsamtools.
.isLastSegment.matrix <- function(x)
{
    is_paired <- as.logical(x[ , "isPaired"])
    is_first0 <- as.logical(x[ , "isFirstMateRead"])
    is_last0 <- as.logical(x[ , "isSecondMateRead"])
    ## According to SAM Spec, bits 0x40 (isFirstMateRead) and 0x80
    ## (isSecondMateRead) can both be set or unset, even when bit 0x1
    ## (isPaired) is set. However we are not interested in those situations
    ## (which have a special meaning).
    is_paired & is_last0 & (!is_first0)
}

.isLastSegment.integer <- function(flag)
{
    bitnames <- c("isPaired", "isFirstMateRead", "isSecondMateRead")
    .isLastSegment.matrix(bamFlagAsBitMatrix(flag, bitnames=bitnames))
}

.isLastSegment.GAlignments <- function(x)
    .isLastSegment.integer(mcols(x)$flag)

### 'x' must be a GAlignments objects.
makeGAlignmentPairs <- function(x, use.names=FALSE, use.mcols=FALSE)
{
    if (!isTRUEorFALSE(use.names))
        stop("'use.names' must be TRUE or FALSE")
    if (!isTRUEorFALSE(use.mcols)) {
        if (!is.character(use.mcols))
            stop("'use.mcols' must be TRUE or FALSE or a character vector ",
                 "specifying the metadata columns to propagate")
        if (!all(use.mcols %in% colnames(mcols(x))))
            stop("'use.mcols' must be a subset of 'colnames(mcols(x))'")
    }
    mate <- findMateAlignment(x)
    x_is_first <- .isFirstSegment.GAlignments(x)
    x_is_last <- .isLastSegment.GAlignments(x)
    first_idx <- which(!is.na(mate) & x_is_first)
    last_idx <- mate[first_idx]

    ## Fundamental property of the 'mate' vector: it's a permutation of order
    ## 2 and with no fixed point on the set of indices for which 'mate' is
    ## not NA.
    ## Check there are no fixed points.
    if (!all(first_idx != last_idx))
        stop("findMateAlignment() returned an invalid 'mate' vector")
    ## Check order 2 (i.e. permuting a 2nd time brings back the original
    ## set of indices).
    if (!identical(mate[last_idx], first_idx))
        stop("findMateAlignment() returned an invalid 'mate' vector")
    ## One more sanity check.
    if (!all(x_is_last[last_idx]))
        stop("findMateAlignment() returned an invalid 'mate' vector")

    ## Check the 0x2 bit (isProperPair).
    x_is_proper <- as.logical(bamFlagAsBitMatrix(mcols(x)$flag,
                                                 bitnames="isProperPair"))
    ans_is_proper <- x_is_proper[first_idx]

    ## Drop pairs with discordant seqnames or strand.
    idx_is_discordant <- (as.character(seqnames(x)[first_idx]) !=
                          as.character(seqnames(x)[last_idx])) |
                         (as.character(strand(x)[first_idx]) ==
                          as.character(strand(x)[last_idx]))
    if (any(idx_is_discordant) != 0L) {
        nb_discordant_proper <- sum(ans_is_proper[idx_is_discordant])
        if (nb_discordant_proper != 0L) {
            ratio <- 100.0 * nb_discordant_proper / sum(idx_is_discordant)
            warning(ratio, "% of the pairs with discordant seqnames or ",
                    "strand were flagged\n",
                    "  as proper pairs by the aligner. Dropping them anyway.")
        }
        keep <- -which(idx_is_discordant)
        first_idx <- first_idx[keep]
        last_idx <- last_idx[keep]
        ans_is_proper <- ans_is_proper[keep]
    }

    ## The big split!
    ans_first <- x[first_idx]
    ans_last <- x[last_idx]
    ans_names <- NULL
    if (use.names)
        ans_names <- names(ans_first)
    names(ans_first) <- names(ans_last) <- NULL
    if (is.character(use.mcols)) {
        mcols(ans_first) <- mcols(ans_first)[use.mcols]
        mcols(ans_last) <- mcols(ans_last)[use.mcols]
    } else if (!use.mcols) {
        mcols(ans_first) <- mcols(ans_last) <- NULL
    }
    GAlignmentPairs(ans_first, ans_last, ans_is_proper, names=ans_names)
}


### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Old stuff.
###

makeGappedAlignmentPairs <- function(...)
    .Defunct("makeGAlignmentPairs")
