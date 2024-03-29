.noGaps <- GAlignments(
    Rle(factor(c("chr1", "chr2", "chr1", "chr3")), 
        c(1, 3, 2, 4)), 
    pos=1:10, cigar=paste0(10:1, "M"),
    strand=Rle(strand(c("-", "+", "*", "+", "-")), 
        c(1, 2, 2, 3, 2)),
    names=head(letters, 10), score=1:10)
.Gaps <- GAlignments(
    Rle(factor(c("chr2", "chr4")), c(3, 4)), pos=1:7,
    cigar=c("5M", "3M2N3M2N3M", "5M", "10M", "5M1N4M", "8M2N1M", "5M"), 
    strand=Rle(strand(c("-", "+")), c(4, 3)),
    names=tail(letters, 7), score=1:7)
GAList <- GAlignmentsList(a=.noGaps, b=.Gaps)
quiet <- suppressWarnings

test_GAlignmentsList_construction <- function() {
    checkTrue(validObject(GAlignmentsList()))
    checkTrue(validObject(new("GAlignmentsList")))
    checkTrue(validObject(GAlignmentsList(.noGaps, .Gaps)))
    checkTrue(validObject(GAlignmentsList(GAlignments())))
    checkTrue(validObject(GAlignmentsList(a=GAlignments())))
    checkException(GAlignmentsList(GRanges()), silent = TRUE)
}

test_GAlignmentsList_coercion <- function() {
    galist <- GAlignmentsList(a=.noGaps[seqnames(.noGaps) == "chr3"], 
                              b=.Gaps[seqnames(.Gaps) == "chr4"])
    ## IRangesList
    rgl <- rglist(galist)
    checkIdentical(length(galist), length(rgl))
    for (i in seq_along(galist)) {
        target <- unlist(rglist(galist[[i]]), use.names=FALSE)
        checkIdentical(target, rgl[[i]])
    }

    ## GRangesList
    grl <- grglist(galist)
    checkIdentical(length(galist), length(grl))
    for (i in seq_along(galist)) {
        target <- unlist(grglist(galist[[i]]), use.names=FALSE)
        checkIdentical(target, grl[[i]])
    }

    ## IntegerRanges
    checkIdentical(length(ranges(galist)), 
                   length(ranges(galist[1])) +
                   length(ranges(galist[2])))
    checkIdentical(length(quiet(granges(galist))), 
                   length(quiet(granges(galist[1]))) +
                   length(quiet(granges(galist[2]))))
    checkIdentical(length(granges(galist, ignore.strand=TRUE)), 
                   length(granges(galist[1], ignore.strand=TRUE)) +
                   length(granges(galist[2], ignore.strand=TRUE)))

    gr <- granges(galist, ignore.strand=TRUE)
    ir <- ranges(galist)
    checkIdentical(length(gr), length(ir))
    gr <- quiet(granges(galist, ignore.strand=FALSE))
    checkTrue(length(gr) == 4L)

    ## data.frame
    galist <- GAlignmentsList(a=.noGaps[1:2], b=.Gaps[1:2])
    df_group <- togroup(PartitioningByWidth(galist))
    df <- data.frame(group=df_group,
                     group_name=names(galist)[df_group],
                     seqnames=factor(c("chr1", rep("chr2", 3)),
                         seqlevels(galist)), 
                     strand=strand(c("-", "+", "-", "-")),
                     cigar=c("10M", "9M", "5M", "3M2N3M2N3M"),
                     qwidth=c(10L, 9L, 5L, 9L), start=c(1L, 2L, 1L, 2L),
                     end=c(10L, 10L, 5L, 14L), width=c(10L, 9L, 5L, 13L),
                     njunc=c(0L, 0L, 0L, 2L), score=c(1L, 2L, 1L, 2L), 
                     row.names=c("a", "b", "t", "u"),
                     stringsAsFactors=FALSE)
    checkTrue(all.equal(as.data.frame(galist), df))

    ## introns
    galist <- GAList
    grl <- junctions(galist)
    checkIdentical(names(galist), names(grl))
    checkTrue(length(galist) == length(grl))
    checkTrue(length(grl[[1]]) == 0L)
    checkTrue(length(grl[[2]]) == 4L)

    ## empty ranges
    galist <- GAlignmentsList(
        GAlignments("chr1", 20, "10M", "+"), GAlignments())
    checkTrue(length(ranges(galist)) == 1L)
    checkTrue(length(rglist(galist)) == 2L)
    checkTrue(length(granges(galist)) == 1L)
    checkTrue(length(grglist(galist)) == 2L)
}

test_GAlignmentsList_accessors <- function() {
    galist <- GAlignmentsList(.noGaps, .Gaps) 
    target <- RleList(lapply(GAList, seqnames), compress=TRUE)
    checkIdentical(seqnames(GAList), target) 
    target <- RleList(lapply(GAList, rname), compress=TRUE)
    checkIdentical(rname(GAList), target)
    target <- CharacterList(lapply(GAList, cigar), compress=TRUE)
    checkIdentical(cigar(GAList), target) 
    target <- RleList(lapply(GAList, strand), compress=TRUE)
    checkIdentical(strand(GAList), target) 
    target <- IntegerList(lapply(GAList, width))
    checkIdentical(width(GAList), target)
    target <- SplitDataFrameList(lapply(GAList, mcols))
    checkIdentical(mcols(GAList, level="within"), target)
}

test_GAlignmentsList_subset_combine <- function()
{
    galist <- GAList
    score <- seq_len(nobj(PartitioningByWidth(galist)))
    meta <- DataFrame(score=score, more=score+10) 
    mcols(galist@unlistData) <- meta

    ## 'c' 
    checkIdentical(GAlignmentsList(), 
                   c(GAlignmentsList(), GAlignmentsList()))
    checkIdentical(GAlignmentsList(.noGaps, .Gaps), 
                   quiet(c(GAlignmentsList(.noGaps), GAlignmentsList(.Gaps))))

    ## '['
    checkIdentical(galist, galist[])
    checkIdentical(galist, galist[Rle(TRUE)])
    checkIdentical(galist[c(TRUE, FALSE),], galist[1])
}

