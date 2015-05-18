Diploma thesis project rendering realistic vegetation in realtime using C++/OpenGL/GLSL/VRUT.

_CTU FEE. Department of Computer Graphics and Interaction_

The main goal of this project is to implement a robust application that can visualize and animate a tree-like object in real time as realisticaly as posible. The application is a module in a modular system called VRUT developed at CTU FEE.

The inspiration and the partial know-how comes from [Ralf Habel](http://www.cg.tuwien.ac.at/staff/RalfHabel.html), Alexander Kusternig, [Michael Wimmer](http://www.cg.tuwien.ac.at/staff/MichaelWimmer.html) and their works focused in that area: [Physically Based Real-Time Translucency for Leaves](http://www.cg.tuwien.ac.at/research/publications/2007/Habel_2007_RTT/) and [Physically Guided ANimation of Trees](http://www.cg.tuwien.ac.at/research/publications/2009/Habel_09_PGT/)

## Actual state of the project ##
  * real-time framerate
  * fully animated 3D model - following the papers mentioned above
  * animated LOD version (pre-rendered slices -> 2D texture + animation)
  * instanced trees -> rendering more than 300 trees in real-time (using 2 levels of detail - full geometry, 3x3 slices )
<a href='http://www.youtube.com/watch?feature=player_embedded&v=WraiCP3gT18' target='_blank'><img src='http://img.youtube.com/vi/WraiCP3gT18/0.jpg' width='425' height=344 /></a>
<a href='http://www.youtube.com/watch?feature=player_embedded&v=eqXCpCINTzQ' target='_blank'><img src='http://img.youtube.com/vi/eqXCpCINTzQ/0.jpg' width='425' height=344 /></a>
<a href='http://www.youtube.com/watch?feature=player_embedded&v=HWZUVE5hgNQ' target='_blank'><img src='http://img.youtube.com/vi/HWZUVE5hgNQ/0.jpg' width='425' height=344 /></a>
<a href='http://www.youtube.com/watch?feature=player_embedded&v=muU_hzCpfHU' target='_blank'><img src='http://img.youtube.com/vi/muU_hzCpfHU/0.jpg' width='425' height=344 /></a>