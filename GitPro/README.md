## Objectives to Learn Git in depth beyond basic commands.

|Your Kindle Notes For:                        |FIELD2       |FIELD3  |FIELD4                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
|----------------------------------------------|-------------|--------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|PRO GIT                                       |             |        |                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
|by Scott Chacon, Ben Straub                   |             |        |                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
|Free Kindle instant preview:                  |             |        |                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
|http://a.co/8mm4Ljb                           |             |        |                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
|----------------------------------------------|             |        |                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
|                                              |             |        |                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
|Annotation Type                               |Location     |Starred?|Annotation                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
|Highlight (Yellow)                            |Location 847 |        |Some of the goals of the new system were as follows: Speed                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
|Highlight (Yellow)                            |Location 848 |        |Simple design Strong support for non-linear development (thousands of parallel branches) Fully distributed Able to handle large projects like the Linux kernel efficiently (speed and data size)                                                                                                                                                                                                                                                                                                                                                                                                                 |
|Highlight (Yellow)                            |Location 854 |        |As you learn Git, try to clear your mind of the things you may know about other VCSs, such as Subversion and Perforce; doing so will help you avoid subtle confusion when using the tool. Git stores and thinks about information much differently than these other systems, even though the user interface is fairly similar, and understanding those differences will help prevent you from becoming confused while using it.                                                                                                                                                                                  |
|Highlight (Yellow)                            |Location 862 |        |Git doesn’t think of or store its data this way. Instead, Git thinks of its data more like                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
|Highlight (Yellow)                            |Location 863 |        |a set of snapshots of a miniature filesystem. Every time you commit, or save the state of your project in Git, it basically takes a picture of what all your files look like at that moment and stores a reference to that snapshot. To be efficient, if files have not changed, Git doesn’t store the file again, just a link to the previous identical file it has already stored. Git thinks about its data more like a stream of snapshots.                                                                                                                                                                  |
|Highlight (Yellow)                            |Location 872 |        |Most operations in Git only need local files and resources to operate—generally no information is needed from another computer on your network. If you’re used to a CVCS where most operations have that network latency overhead, this aspect of Git will make you think that the gods of speed have blessed Git with unworldly powers.                                                                                                                                                                                                                                                                         |
|Highlight (Yellow)                            |Location 877 |        |If you want to see the changes introduced between the current version of a file and the file a month ago, Git can look up the file a month ago and do a local difference calculation, instead of having to either ask a remote server to do it or pull an older version of the file                                                                                                                                                                                                                                                                                                                              |
|Highlight (Yellow)                            |Location 884 |        |Everything in Git is check-summed before it is stored and is then referred to by that checksum.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
|Highlight (Yellow)                            |Location 887 |        |The mechanism that Git uses for this checksumming is called a SHA-1 hash.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
|Highlight (Yellow)                            |Location 896 |        |Git has three main states that your files can reside in: committed, modified, and staged. Committed means that the data is safely stored in your local database. Modified means that you have changed the file but have not committed it to your database yet. Staged means that you have marked a modified file in its current version to go into your next commit snapshot.                                                                                                                                                                                                                                    |
|Highlight (Yellow)                            |Location 899 |        |This leads us to the three main sections of a Git project: the Git directory, the working directory, and the staging area.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
|Highlight (Yellow)                            |Location 902 |        |metadata and object database for your project. This is the most important part of Git, and it is what is copied when you clone a repository from another computer. The working directory is a single checkout of one version of the project. These files are pulled out of the compressed database in the Git directory and placed on disk for you to use or modify. The staging area is a file, generally contained in your Git directory, that stores information about what will go into your next commit. It’s sometimes referred to as the “index”, but it’s also common to refer to it as the staging area.|
|Highlight (Yellow)                            |Location 907 |        |1. You modify files in your working directory.   2. You stage the files, adding snapshots of them to your staging area.   3. You do a commit, which takes the files as they are in the staging area and stores that snapshot permanently to your Git directory.                                                                                                                                                                                                                                                                                                                                                  |
|Highlight (Yellow)                            |Location 973 |        |Each level overrides values in the previous level, so values in .git/config trump those in /etc/gitconfig.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
|Highlight (Yellow)                            |Location 1085|        |git add is a multipurpose command—you use it to begin tracking new files, to stage files, and to do other things like marking merge-conflicted files as resolved. It may be helpful to think of it more as “add this content to the next commit” rather than “add this file to the project”. Let’s run git add now to stage the benchmarks.rb                                                                                                                                                                                                                                                                    |