module load gatk/4.1.7.0

mkdir busblog
mkdir bsub_submit

foreach sample ("`cat samples.list`") 
foreach chr ("`cat chrs.list`") 
echo  bsub_submit/${sample}_${chr}.lsf
echo  bsub_submit/${sample}_${chr}.csh
echo  bsub_submit/sbumit.${sample}_${chr}.csh


cat <<EOF > bsub_submit/${sample}_${chr}.lsf

#BSUB -J ${sample}_$chr 
#BSUB -W 10:00 
#BSUB -o byC/busblog/${sample}_${chr}.o 
#BSUB -e byC/busblog/${sample}_${chr}.err 
#BSUB -cwd byC/ 
#BSUB -q medium 
#BSUB -n 7
#BSUB -M 50 
#BSUB -R rusage[mem=40]
module load singularity/3.2.0 
module load snakemake/5.10.0 
module load gatk/4.1.7.0

tcsh bsub_submit/${sample}_${chr}.csh

EOF

cat <<EOFA > bsub_submit/${sample}_${chr}.csh
if ( -f called/${sample}_${chr}.3.f1r2.tar.gz) then
        echo "called/${sample}_${chr}.3.f1r2.tar.gz exists."
else
        $run_gatk gatk Mutect2\
        -R hg38/resources_broad_hg38_v0_Homo_sapiens_assembly38.fasta \
        -I recal/${sample}-tumor.bam \
        -I recal/Normal.bam \
        -tumor ${sample}_tumor \
        -normal  Normal \
        -pon hg38/pon2/gmcl.pon.vcf.gz \
        --germline-resource hg38/af-only-gnomad.hg38.vcf.gz \
        -L hg38/${chr}.interval_list \
        -bamout called/${sample}_${chr}.2_somatic_m2.unfiltered.bam \
        --f1r2-tar-gz called/${sample}_${chr}.3.f1r2.tar.gz \
        -O called/${sample}_${chr}.1_somatic_m2.unfiltered.vcf.gz
endif 

if ( -f called/${sample}_${chr}.4.read-orientation-model.tar.gz) then
        echo "called/${sample}_${chr}.4.read-orientation-model.tar.gz exists."
else
        $run_gatk gatk LearnReadOrientationModel \
        -I called/${sample}_${chr}.3.f1r2.tar.gz \
        -O called/${sample}_${chr}.4.read-orientation-model.tar.gz
endif 

if ( -f called/${sample}_${chr}.7_tumor_getpileupsummaries.table) then
        echo "called/${sample}_${chr}.7_tumor_getpileupsummaries.table exit"
else
        $run_gatk gatk GetPileupSummaries \
        -I called/${sample}_${chr}.2_somatic_m2.unfiltered.bam \
        -V hg38/small_exac_common_3.hg38.vcf.gz \
        -L hg38/${chr}.interval_list \
        -O called/${sample}_${chr}.7_tumor_getpileupsummaries.table
endif

if ( -f called/${sample}_${chr}.8_tumor_calculatecontamination.table) then
        echo "called/${sample}_${chr}.8_tumor_calculatecontamination.table exit"

else
        $run_gatk gatk CalculateContamination \
        -I called/${sample}_${chr}.7_tumor_getpileupsummaries.table \
        -tumor-segmentation called/${sample}_${chr}.9_tumor_segments.table \
        -O called/${sample}_${chr}.8_tumor_calculatecontamination.table
endif

if ( -f called/${sample}_${chr}.9_somatic_oncefiltered.vcf.gz) then
        echo "called/${sample}_${chr}.9_somatic_oncefiltered.vcf.gz exit"
else      
        $run_gatk  gatk FilterMutectCalls \
        -R hg38/resources_broad_hg38_v0_Homo_sapiens_assembly38.fasta \
        -V called/${sample}_${chr}.1_somatic_m2.unfiltered.vcf.gz  \
        --tumor-segmentation called/${sample}_${chr}.9_tumor_segments.table \
        --contamination-table called/${sample}_${chr}.8_tumor_calculatecontamination.table  \
        --ob-priors called/${sample}_${chr}.4.read-orientation-model.tar.gz \
        -O called/${sample}_${chr}.9_somatic_oncefiltered.vcf.gz
endif

EOFA


cat <<EOFC > bsub_submit/sbumit.${sample}_${chr}.csh
if ( -f called/${sample}_${chr}.9_somatic_oncefiltered.vcf.gz) then
        echo "called/${sample}_${chr}.9_somatic_oncefiltered.vcf.gz exit"
else
        bsub < bsub_submit/${sample}_${chr}.lsf
endif
EOFC

tcsh bsub_submit/sbumit.${sample}_${chr}.csh


end
end
