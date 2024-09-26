#!/bin/bash
set -x
set -e
INPUT_DIR=./test
FFMPEG=ffmpeg
MAGICK=magick
# https://vcgit.hhi.fraunhofer.de/jvet/VVCSoftware_VTM
VVC=/home/ichlubna/Workspace/VVCSoftware_VTM/
# https://github.com/divideon/xvc/tree/master
XVC=/home/ichlubna/Workspace/xvc/build/app/
# https://github.com/richzhang/PerceptualSimilarity
LPIPS=/home/ichlubna/Workspace/PerceptualSimilarity/
# https://github.com/dingkeyan93/DISTS
DISTS=/home/ichlubna//Workspace/DISTS/DISTS_pytorch/

TEMP=$(mktemp -d)
RESULTS=./results.txt
HEADER="compressed, reference, pixfmt, file, codec, time, crf, size, psnr, ssim, vmaf, dists, lpips"
echo $HEADER > $RESULTS

compareAndStore ()
{
    INPUT=$1
    REFERENCE_INPUT=$2
    RESULT=$($FFMPEG -i $INPUT -i $REFERENCE_INPUT -filter_complex "psnr" -f null /dev/null 2>&1)
    PSNR=$(echo "$RESULT" | grep -oP '(?<=average:).*?(?= min)')
    RESULT=$($FFMPEG -i $INPUT -i $REFERENCE_INPUT -filter_complex "ssim" -f null /dev/null 2>&1)
    SSIM=$(echo "$RESULT" | grep -oP '(?<=All:).*?(?= )')
    RESULT=$($FFMPEG -i $INPUT -i $REFERENCE_INPUT -lavfi libvmaf -f null /dev/null 2>&1)
    VMAF=$(echo "$RESULT" | grep -oP '(?<=VMAF score: ).*')
    $FFMPEG -y -i $1 -pix_fmt rgb48be $TEMP/1.png
    $FFMPEG -y -i $2 -pix_fmt rgb48be $TEMP/2.png
    cd $DISTS
    DISTS_VAL=$(python DISTS_pt.py --dist $TEMP/1.png --ref $TEMP/2.png)
    cd -   
    cd $LPIPS
    LPIPS_VAL=$(python lpips_2imgs.py -p0 $TEMP/1.png -p1 $TEMP/2.png --use_gpu)
    LPIPS_VAL=$(printf '%s\n' "${LPIPS_VAL#*Distance: }")
    cd - 
    echo $1, $2, $3, $4, $5, $6, $7, $8, $PSNR, $SSIM, $VMAF, $DISTS_VAL, $LPIPS_VAL >> $RESULTS 
}

REFERENCE=$TEMP/reference.exr

for FILE in $INPUT_DIR/*.NEF; do
    $MAGICK $FILE -compress NONE $REFERENCE
    COMPRESSED=$TEMP/compressed.exr
    for PIXFMT in yuv420p yuv422p yuv444p yuv420p10le yuv422p10le yuv444p10le yuv420p12le yuv422p12le yuv444p12le; do
        START=$(date +%s.%N)
        $FFMPEG -y -i $REFERENCE -c:v libx265 -crf 0 -x265-params lossless=1 -pix_fmt $PIXFMT $TEMP/$PIXFMT.mkv
        END=$(date +%s.%N)
        ELAPSED=$(echo "$END - $START" | bc)
        SIZE=$(stat --printf="%s" $TEMP/$PIXFMT.mkv)
        $MAGICK $TEMP/$PIXFMT.mkv -compress NONE $COMPRESSED
        compareAndStore $COMPRESSED $REFERENCE $PIXFMT $FILE 0 $ELAPSED 0 $SIZE 
    done
    for PIXFMT in rgb24 rgb48le; do
        START=$(date +%s.%N)
        $FFMPEG -y -i $REFERENCE -c:v libjxl -q:v 0 -pix_fmt $PIXFMT $TEMP/$PIXFMT.jxl
        END=$(date +%s.%N)
        ELAPSED=$(echo "$END - $START" | bc)
        SIZE=$(stat --printf="%s" $TEMP/$PIXFMT.jxl)
        $MAGICK $TEMP/$PIXFMT.jxl -compress NONE $COMPRESSED
        compareAndStore $COMPRESSED $REFERENCE $PIXFMT $FILE 0 $ELAPSED 0 $SIZE 
    done
    
    CODEC=libx265
    COMPRESSED=$TEMP/compressed.mkv
    for CRF in 0 9 17 25 33 41 49; do
        for PIXFMT in yuv420p yuv422p yuv444p yuv420p10le yuv422p10le yuv444p10le yuv420p12le yuv422p12le yuv444p12le; do
            START=$(date +%s.%N)
            $FFMPEG -y -i $TEMP/$PIXFMT.mkv -c:v $CODEC -crf $CRF -pix_fmt $PIXFMT $COMPRESSED
            END=$(date +%s.%N)
            ELAPSED=$(echo "$END - $START" | bc)
            SIZE=$(stat --printf="%s" $COMPRESSED)
            compareAndStore $COMPRESSED $TEMP/$PIXFMT.mkv $PIXFMT $FILE $CODEC $ELAPSED $CRF $SIZE 
        done
    done
    
    CODEC=libaom-av1
    for CRF in 0 9 18 27 36 45 54; do
        for PIXFMT in yuv420p yuv422p yuv444p yuv420p10le yuv422p10le yuv444p10le yuv420p12le yuv422p12le yuv444p12le; do
            START=$(date +%s.%N)
            $FFMPEG -y -i $TEMP/$PIXFMT.mkv -c:v $CODEC -crf $CRF -pix_fmt $PIXFMT -cpu-used 8 -row-mt 1 -tiles 2x2 $COMPRESSED
            END=$(date +%s.%N)
            ELAPSED=$(echo "$END - $START" | bc)
            SIZE=$(stat --printf="%s" $COMPRESSED)
            compareAndStore $COMPRESSED $TEMP/$PIXFMT.mkv $PIXFMT $FILE $CODEC $ELAPSED $CRF $SIZE 
        done
    done

    CODEC=vvc
    COMPRESSED=$TEMP/vvc.bin
    for CRF in 0 10 19 28 37 46 55; do
        for PIXFMT in yuv420p yuv422p yuv444p yuv420p10le yuv422p10le yuv444p10le yuv420p12le yuv422p12le yuv444p12le; do
            CHROMA=$(grep -oP '(?<=yuv).*?(?=p)' <<< $PIXFMT)
            DEPTH=10
            if [[ $PIXFMT == *"12le"* ]]; then
                DEPTH=12
            fi
            $FFMPEG -y -i $TEMP/$PIXFMT.mkv -strict -1 -pix_fmt $PIXFMT $TEMP/input.y4m
            START=$(date +%s.%N)
            $VVC/bin/EncoderAppStatic --AdaptBypassAffineMe --BcwFast --FastLFNST --TransformSkipFast --ISPFast --FastLocalDualTreeMode 2 --FastMEAssumingSmootherMVEnabled --AlfLambdaOpt --AffineAmvrEncOpt --ContentBasedFastQtbt --FEN 1 -fr 25 --InputChromaFormat=$CHROMA -i $TEMP/input.y4m -c $VVC/cfg/encoder_lowdelay_P_vtm.cfg -c $VVC/cfg/444/yuv444.cfg --InternalBitDepth=$DEPTH -q $CRF -f 1 -b $COMPRESSED
            END=$(date +%s.%N)
            ELAPSED=$(echo "$END - $START" | bc)
            DECOMPRESSED=$TEMP/output.y4m
            $VVC/bin/DecoderAppStatic -b $COMPRESSED -o $DECOMPRESSED
            SIZE=$(stat --printf="%s" $COMPRESSED)
            compareAndStore $DECOMPRESSED $TEMP/$PIXFMT.mkv $PIXFMT $FILE $CODEC $ELAPSED $CRF $SIZE 
        done
    done
    
    CODEC=xvc
    COMPRESSED=$TEMP/xvc.bin
    for CRF in 0 10 19 28 37 46 55; do
        for PIXFMT in yuv420p yuv422p yuv444p yuv420p10le yuv422p10le yuv444p10le yuv420p12le yuv422p12le yuv444p12le; do
            DEPTH=10
            if [[ $PIXFMT == *"12le"* ]]; then
                DEPTH=12
            fi
            CHROMA=1
            if [[ $PIXFMT == *"422p"* ]]; then
                CHROMA=2
            elif [[ $PIXFMT == *"444p"* ]]; then
                CHROMA=3
            fi
            $FFMPEG -y -i $TEMP/$PIXFMT.mkv -strict -1 -pix_fmt $PIXFMT $TEMP/input.y4m
            START=$(date +%s.%N)
            $XVC/xvcenc -input-chroma-format $CHROMA -internal-bitdepth $DEPTH -input-file $TEMP/input.y4m -qp $CRF -output-file $COMPRESSED 
            END=$(date +%s.%N)
            ELAPSED=$(echo "$END - $START" | bc)
            DECOMPRESSED=$TEMP/output.y4m
            $XVC/xvcdec -bitstream-file $COMPRESSED -output-file $DECOMPRESSED 
            SIZE=$(stat --printf="%s" $COMPRESSED)
            compareAndStore $DECOMPRESSED $TEMP/$PIXFMT.mkv $PIXFMT $FILE $CODEC $ELAPSED $CRF $SIZE 
        done
    done

    CODEC=libjxl
    COMPRESSED=$TEMP/jxl.jxl
    for CRF in 0 35 45 60 70 85 100; do
        for PIXFMT in rgb24 rgb48le; do
            START=$(date +%s.%N)
            $FFMPEG -y -i $REFERENCE -c:v $CODEC -q:v $CRF -pix_fmt $PIXFMT $COMPRESSED
            END=$(date +%s.%N)
            ELAPSED=$(echo "$END - $START" | bc)
            SIZE=$(stat --printf="%s" $COMPRESSED)
            compareAndStore $COMPRESSED $TEMP/$PIXFMT.jxl $PIXFMT $FILE $CODEC $ELAPSED $CRF $SIZE 
        done
    done

    CODEC=libwebp
    COMPRESSED=$TEMP/webp.webp
    for CRF in 0 35 45 60 70 85 100; do
        PIXFMT=yuv420p
        START=$(date +%s.%N)
        $FFMPEG -y -i $REFERENCE -c:v $CODEC -q:v $CRF -pix_fmt $PIXFMT $COMPRESSED
        END=$(date +%s.%N)
        ELAPSED=$(echo "$END - $START" | bc)
        SIZE=$(stat --printf="%s" $COMPRESSED)
        compareAndStore $COMPRESSED $TEMP/$PIXFMT.mkv $PIXFMT $FILE $CODEC $ELAPSED $CRF $SIZE 
    done 
    
    CODEC=exr
    COMPRESSED=$TEMP/exr.exr
    for COMPRESSION in RLE ZIP Piz Pxr24 B44 DWAA DWAB; do
        START=$(date +%s.%N)
        $MAGICK $REFERENCE -compress $COMPRESSION $COMPRESSED 
        END=$(date +%s.%N)
        ELAPSED=$(echo "$END - $START" | bc)
        SIZE=$(stat --printf="%s" $COMPRESSED)
        DECOMPRESSED=$TEMP/exr.png
        $MAGICK $COMPRESSED -depth 16 $DECOMPRESSED
        compareAndStore $DECOMPRESSED $REFERENCE $COMPRESSION $FILE $CODEC $ELAPSED 0 $SIZE 
    done  
done
rm -rf $TEMP
