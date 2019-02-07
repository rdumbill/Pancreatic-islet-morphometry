var backgroundArea=0;
var Ins_area=0;
var Glu_area=0;

macro "mark3 [i]"	{

//Initialisation
setBatchMode(true);
setOption("ExpandableArrays", true);

input=getDirectory("Select the directory");

Dialog.create("Mode");
Dialog.addNumber("Smooth/ shrink operations applied to background",6);
Dialog.show();

var shrinks=Dialog.getNumber();
var q=100;
var kurtosis=0.001;


filename=File.getName(input);
ch1=filename+"_raw02.pic";
ch3=filename+"_raw03.pic";

//Find whole islet area
open (input+ch1);
open (input+ch3);
getPixelSize(unit, pixelWidth, pixelHeight);
run("Merge Channels...", "c1=["+ch1+"] c3=["+ch3+"]");
rename("TwoChannelOriginal");
run("Duplicate...", " ");
rename("WholeIsletArea");
run("Maximum...", "radius=4");
run("8-bit");
run("Auto Threshold", "method=Triangle white");
run("Make Binary");
run("Fill Holes");
run("Invert");
run("RGB Color");
run("Concatenate...", "  title=[Concatenated Stacks] image1=TwoChannelOriginal image2=WholeIsletArea image3=[-- None --]");
setBatchMode("show");
setTool("wand");
waitForUser("Select all required components of mask using wand and shift+click, then click OK");
roiManager("Add");
run("Stack to Images");
selectWindow("Concatenated-0001");
rename("TwoChannelOriginal");
selectWindow("Concatenated-0002");
rename("WholeIsletArea");
selectWindow("WholeIsletArea");
roiManager("Select", 0);
run("Clear Outside");
run("Convert to Mask");
for (m=0; m<shrinks; m++) {
	run("Dilate");
	}
run("Fill Holes");
for (m=0; m<shrinks+1; m++) {
    run("Erode");
	}
if (shrinks>0)	{
	run("Median...", "radius=5");
	run("Create Selection");
	roiManager("Delete");
	roiManager("Add");
}

else	{
	roiManager("Select", 0);
	run("Clear", "slice");
}
run("Set Scale...", "distance="+1/pixelWidth+" known=1 unit=unit");
getStatistics(backgroundArea);
setResult("Islet", nResults, filename);
setResult("Islet Area", nResults-1, backgroundArea);
run("Select All");
run("Invert");
rename("Background");

//Find combined signal area using area/perimeter method
open (input+ch1);
run("Enhance Contrast", "saturated=0.02");
open (input+ch3);
run("Enhance Contrast", "saturated=0.02");

run("Merge Channels...", "c1=["+ch1+"] c3=["+ch3+"] create");
run("RGB Color");
rename("8bit_stack");
run("8-bit");
Signal_array = newArray;
for (i=0; i<255; i++) {
		run("Duplicate...", " ");
		setThreshold(i, 255);
		run("Create Selection");
		List.setMeasurements;
		a=List.getValue("Area");
		p=List.getValue("Perim.");
		Signal_array[i] = a/p;
		close();
	}
Sig_peaks = Array.findMaxima (Signal_array,kurtosis,1);
while (Sig_peaks.length >1)	{
Sig_peaks = Array.findMaxima (Signal_array,kurtosis,1);
kurtosis = kurtosis + 0.001;
}
Array.sort(Sig_peaks);

Sig_peak = 28+10*atan(((Sig_peaks[0]/10)-3))+0.001*(Sig_peaks[0]-30)^2-0.05*(Sig_peaks[0]-30);
selectWindow("8bit_stack");
setThreshold(0, Sig_peak);
run("Convert to Mask");
roiManager("Select", 0);
setBackgroundColor(0, 0, 0);
run("Clear Outside");
run("Create Selection");
run("Make Inverse");
roiManager("Add");
close();

//Regional merging, histogram equalisation, and background elimination for each individual signal
open (input+ch1);
open (input+ch3);
selectWindow(ch1);
run("Statistical Region Merging", "q="+q+" showaverages");
run("Select All");
List.setMeasurements();
G=List.getValue("Mode");
roiManager("Select", 1);
run("Clear Outside");
selectWindow(ch3);
run("Statistical Region Merging", "q="+q+" showaverages");
run("Select All");
List.setMeasurements();
I=List.getValue("Mode");
roiManager("Select", 1);
run("Clear Outside");

if (I>G)	{
	selectWindow(ch1);
	run("Multiply...", "value="+(I/G)+"");
}
if (G>I)	{
	selectWindow(ch3);
	run("Multiply...", "value="+(G/I)+"");
}

run("Merge Channels...", "c1=["+ch1+" (SRM Q="+q+".0)] c3=["+ch3+" (SRM Q="+q+".0)] create");
run("RGB Color");
run("Duplicate...", " ");

//Segmentation - glucagon
width = getWidth();
height = getHeight();

for (x=0; x<width; x++)	{
	for (y=0; y<width; y++)	{
		v=getPixel(x,y);
		red = (v>>16)&0xff;
		blue = v&0xff;
		if (red>blue)	{
			setPixel(x,y,255);
		}
		if (blue>red)	{
			setPixel(x,y,0);
		}
		if (blue==red && blue <10)	{
			setPixel(x,y,0);
		}
		if (blue==red && blue >10)	{
			setPixel(x,y,255);
		}
	}
}

rename("Glu");
updateDisplay();
run("8-bit");
run("Auto Threshold", "method=Default white");
roiManager("Select",0);
run("Clear Outside");
run("Create Selection");
run("Make Inverse");
run("Set Scale...", "distance="+1/pixelWidth+" known=1 unit=unit");
getStatistics(Glu_area);
setResult("Glucagon Area", nResults-1, Glu_area);
updateResults();

//Segmentation - insulin
selectWindow("Composite (RGB)");

for (x=0; x<width; x++)	{
	for (y=0; y<width; y++)	{
		v=getPixel(x,y);
		red = (v>>16)&0xff;
		blue = v&0xff;
		if (blue>red)	{
			setPixel(x,y,255);
		}
		if (red>blue)	{
			setPixel(x,y,0);
		}
		if (blue==red && blue <10)	{
			setPixel(x,y,0);
		}
		if (blue==red && blue >10)	{
			setPixel(x,y,255);
		}
	}
}
rename("Ins");
updateDisplay();
run("8-bit");
run("Auto Threshold", "method=Default white");
roiManager("Select",0);
run("Clear Outside");
run("Create Selection");
run("Make Inverse");
run("Set Scale...", "distance="+1/pixelWidth+" known=1 unit=unit");
getStatistics(Ins_area);
setResult("Insulin Area", nResults-1, Ins_area);

updateResults();

//Produced merged segmentation
run("Merge Channels...", "c1=Glu c3=Ins c4=Background create");
run("RGB Color");
close("Composite");
close("Composite");
close(ch1);
close(ch3);
run("Images to Stack", "name=Stack title=[] use");
run("Make Montage...", "columns=2 rows=1 scale=1");
selectWindow("Stack");
close();
roiManager("Delete");
setBatchMode(false);
}