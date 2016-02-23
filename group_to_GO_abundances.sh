#!/bin/bash

function msg_error() {
    printf "ERROR\n%15s   %s\n\n" "$1"
}

function prettyOpt() {
    printf "%15s   %s\n" "$1" "$2"
}

function shortUsage() {
    echo -e "Usage:\n\tgroup_to_GO_abundances [OPTIONS] -i humann2_gene_families_abundance -o go_slim_term_abundance"
    echo

    echo "Required options:"
    prettyOpt "-i" "Path to file with UniRef50 gene family abundance (HUMAnN2 output)"
    prettyOpt "-m" "Path to file which will contain GO slim term abudances corresponding to molecular functions"
    prettyOpt "-b" "Path to file which will contain GO slim term abudances corresponding to biological processes"
    prettyOpt "-c" "Path to file which will contain GO slim term abudances corresponding to cellular components"
    echo
    echo "Other options:"
    prettyOpt "-a" "Path to basic Gene Ontology file"
    prettyOpt "-s" "Path to basic slim Gene Ontology file"
    prettyOpt "-u" "Path to file with HUMAnN2 correspondance betwen UniRef50 and GO"
    prettyOpt "-g" "Path to GoaTools scripts"
    prettyOpt "-p" "Path to HUMAnN2 scripts"

    prettyOpt "-h" "Print this help message"

    echo
    exit 0
}

MY_PATH=`dirname "$0"`

input_file=""
molecular_function_file=""
biological_processes_file=""
cellular_component_file=""
go_file=$MY_PATH"/data/go.obo"
slim_go_file=$MY_PATH"/data/goslim_metagenomics.obo"
humann2_uniref_go=$MY_PATH"/data/map_infogo1000_uniref50.txt"
goatools_path="goatools/scripts/"
humann2_path="/usr/bin/"

# Manage arguments
while getopts ":i:m:b:c:a:s:u:g:p:h" opt; do
    case $opt in
        i)
            input_file=$OPTARG >&2
            ;;
        m)
            molecular_function_file=$OPTARG >&2
            ;;
        b)
            biological_processes_file=$OPTARG >&2
            ;;
        c)
            cellular_component_file=$OPTARG >&2
            ;;
        a)
            go_file=$OPTARG >&2
            ;;
        s)
            slim_go_file=$OPTARG >&2
            ;;
        u)
            humann2_uniref_go=$OPTARG >&2
            ;;
        g)
            goatools_path=$OPTARG >&2
            ;;
        p)
            humann2_path=$OPTARG >&2
            ;;
        h)
            shortUsage ;
            break
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
        
        :)
            echo "Option -$OPTARG requires an argument." >&2
            exit 1
            ;;
  esac
done

if [ -z $input_file ]; then
    msg_error "Missing argument: -i"
    shortUsage;
fi

if [ -z $molecular_function_file ]; then
    msg_error "Missing argument: -m"
    shortUsage;
fi

if [ -z $biological_processes_file ]; then
    msg_error "Missing argument: -b"
    shortUsage;
fi

if [ -z $cellular_component_file ]; then
    msg_error "Missing argument: -c"
    shortUsage;
fi

# Scripts
$MY_PATH"/download_datasets.sh"

tmp_data_dir="tmp_data"
if [ ! -d $tmp_data_dir ]; then
    mkdir $tmp_data_dir
fi

if [ -d .venv ]; then
    source .venv/bin/activate
fi

echo "Format HUMAnN2 UniRef50 GO mapping"
echo "=================================="
python $MY_PATH"/src/format_humann2_uniref_go_mapping.py" \
    --uniref_go_mapping_input $humann2_uniref_go \
    --uniref_go_mapping_output $tmp_data_dir"/uniref_go_mapping_output.txt" \
    --go_names $tmp_data_dir"/humann2_go_names.txt"
echo ""

echo "Map to slim GO"
echo "=============="
python $goatools_path"/map_to_slim.py" \
    --association_file $tmp_data_dir"/humann2_go_names.txt" \
    $go_file \
    $slim_go_file \
    > $tmp_data_dir"/humman2_go_slim.txt"
echo ""

echo "Format slim GO"
echo "=============="
python $MY_PATH"/src/format_go_correspondance.py" \
    --go_correspondance_input $tmp_data_dir"/humman2_go_slim.txt" \
    --go_correspondance_output $tmp_data_dir"/formatted_humman2_go_slim.txt"
echo ""

echo "Regroup UniRef50 to GO"
echo "======================"
$humann2_path/humann2_regroup_table \
    -i $input_file \
    -f "sum" \
    -c $tmp_data_dir"/uniref_go_mapping_output.txt" \
    -o $tmp_data_dir"/humann2_go_abundances.txt"
echo ""

echo "Regroup GO to slim GO"
echo "====================="
$humann2_path/humann2_regroup_table \
    -i $tmp_data_dir"/humann2_go_abundances.txt" \
    -f "sum" \
    -c $tmp_data_dir"/formatted_humman2_go_slim.txt" \
    -o $tmp_data_dir"/humann2_slim_go_abundances.txt"
echo ""

echo "Format slim GO abundance"
echo "========================"
python $MY_PATH"/src/format_humann2_output.py" \
    --go_slim $slim_go_file \
    --humann2_output $tmp_data_dir"/humann2_slim_go_abundances.txt" \
    --molecular_function_output_file $molecular_function_file \
    --biological_processes_output_file $biological_processes_file \
    --cellular_component_output_file $cellular_component_file
echo ""

#rm -rf $tmp_data_dir
