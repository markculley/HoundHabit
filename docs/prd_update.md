# Updates prd.md

Date April 14, 2026

## Training Plans

The following is a summary of the changes to the Training Plan.

1. Add a new object "Behavior" that is a child of the Training Plan object and a parent of the Steps object

1. On TrainerPlanDetailView, group the "Assigned To" label and Text with the Training Plan text and description

1. TrainerPlanDetailView will now show a list of "Behavior" names, not "Steps". The must be a button os some sort to "Add Behavior".

1. The the "Assigned To" text is a button with label "Assign" if no assignment has been made. After an assignment is made, the "Assigned To" text is the name of the Guardian, just like it is now.

## Add new Behavior view

1. After clicking on a Behavior in the Behavior list in TrainerPlanDetailView, a Behavior detail view should be shown. The Behavior has the following properties: Name, a list of "Step"s.
    1. When the user clicks on the Name text, the app should suggest the following default values:

    - sit
    - down
    - leave it
    - drop it
    - stand
    - wait/stay
    - walk
    - touch
    - go to matt
    - recall
    - off
    - attention

## Step View

1. The three D's are static. Add the ability of a user to enter a cuatom value for each D.  The default values of each D are:

    1. Distance - Arm, 6ft, 12ft
    1. Duration - Instant, 5 seconds
    1. Distraction - None, Any