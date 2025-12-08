import 'package:flutter/material.dart';
import 'package:swiftlead/components/custom_bottom_navigation.dart';
import 'package:swiftlead/pages/blog_page.dart';

class BlogMenu extends StatefulWidget {
  const BlogMenu({super.key});

  @override
  State<BlogMenu> createState() => _BlogMenuState();
}

class _BlogMenuState extends State<BlogMenu> {

  double width(BuildContext context) => MediaQuery.of(context).size.width;
  double height(BuildContext context) => MediaQuery.of(context).size.height;
  
  int _currentIndex = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        
        automaticallyImplyLeading: true,
        title: const Text("Berita Terkini", style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.w500),),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
          Padding(
                 padding: EdgeInsets.only(bottom: height(context) * 0.02),
                 child: GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const BlogPage()));
                  },
                   child: Container(
                    
                    alignment: Alignment.center,
                    width: width(context) * 0.8,
                    height: height(context) * 0.25,
                    
                                 
                    decoration: BoxDecoration(
                    
                      color: const Color(0xFFFFF7CA),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: List<BoxShadow>.from([
                        const BoxShadow(
                          color: Colors.black26,
                          blurRadius: 2,
                          offset: Offset(2, 2),
                        ),
                      ]),
                      ),
                      child: Stack(
                        children: [
                          Container(
                           width: width(context) * 0.8,
                          height: height(context) * 0.20,
                          decoration: const BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage("assets/img/Frame_19.png"),
                              fit: BoxFit.cover
                            ),
                            borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8))
                          ),
                          ),
                          Column(
                            children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(left:8.0, top: 8),
                                  child: Container(
                                   
                                    width: width(context) * 0.1,
                                    height: height(context) * 0.02,
                                    decoration: BoxDecoration(
                                      
                                      color: Colors.white.withAlpha(140),
                                      borderRadius: BorderRadius.circular(8),
                                    
                                    ),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: [
                          
                                      Icon(Icons.visibility, color: Color((0xFF0010a2)), size: 10,),
                                      Text("1,2rb", style: TextStyle(fontSize: 10, color: Color(0xFF0010a2), ),
                                       textAlign: TextAlign.center,)
                                    ],),
                                  ),
                                ),
                              ],
                            ),
                            
                            ],
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                width: width(context) * 0.8,
                                height: height(context) * 0.05,
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.only(left: 8),  
                                decoration: const BoxDecoration(
                                  color: Color(0xffe9f9ff), 
                      
                                ),
                                child: const Text("Cara Melakukan Budidaya Burung Walet", style: TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.w400),),
                              
                              
                              ),
                            ],
                          )
                          
                          
                          
                        ],
                      ),
                      
                   ),
                 ),
               ),
               Padding(
                 padding: const EdgeInsets.only(bottom:24.0, top: 24),
                 child: Container(
                  
                  alignment: Alignment.center,
                  width: width(context) * 0.8,
                  height: height(context) * 0.25,
                  
                               
                  decoration: BoxDecoration(
                  
                    color: const Color(0xFFFFF7CA),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: List<BoxShadow>.from([
                      const BoxShadow(
                        color: Colors.black26,
                        blurRadius: 2,
                        offset: Offset(2, 2),
                      ),
                    ]),
                    ),
                    child: Stack(
                      children: [
                        Container(
                         width: width(context) * 0.8,
                        height: height(context) * 0.20,
                        decoration: const BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage("assets/img/images_(1).jpg"),
                            fit: BoxFit.cover
                          ),
                          borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8))
                        ),
                        ),
                        Column(
                          children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left:8.0, top:8),
                                child: Container(
                                 
                                  width: width(context) * 0.1,
                                  height: height(context) * 0.02,
                                  decoration: BoxDecoration(
                                    
                                    color: Colors.white.withAlpha(140),
                                    borderRadius: BorderRadius.circular(8),
                                  
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                        
                                    Icon(Icons.visibility, color: Color((0xFF0010a2)), size: 10,),
                                    Text("1,2rb", style: TextStyle(fontSize: 10, color: Color(0xFF0010a2), ),
                                     textAlign: TextAlign.center,)
                                  ],),
                                ),
                              ),
                            ],
                          ),
                          
                          ],
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                                width: width(context) * 0.8,
                                height: height(context) * 0.05,
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.only(left: 8),  
                                decoration: const BoxDecoration(
                                  color: Color(0xffe9f9ff), 
                      
                                ),
                                child: const Text("Cara Melakukan Budidaya Burung Walet", style: TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.w400),),
                              
                              
                              ),
                          ],
                        )
                        
                        
                        
                      ],
                    ),
                    
                 ),
               ),
               Padding(
                 padding: const EdgeInsets.only(bottom:24.0, top: 24),
                 child: Container(
                  
                  alignment: Alignment.center,
                  width: width(context) * 0.8,
                  height: height(context) * 0.25,
                  
                               
                  decoration: BoxDecoration(
                  
                    color: const Color(0xFFFFF7CA),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: List<BoxShadow>.from([
                      const BoxShadow(
                        color: Colors.black26,
                        blurRadius: 2,
                        offset: Offset(2, 2),
                      ),
                    ]),
                    ),
                    child: Stack(
                      children: [
                        Container(
                         width: width(context) * 0.8,
                        height: height(context) * 0.20,
                        decoration: const BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage("assets/img/download_(3).jpg"),
                            fit: BoxFit.cover
                          ),
                          borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8))
                        ),
                        ),
                        Column(
                          children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left:8.0, top:8),
                                child: Container(
                                 
                                  width: width(context) * 0.1,
                                  height: height(context) * 0.02,
                                  decoration: BoxDecoration(
                                    
                                    color: Colors.white.withAlpha(140),
                                    borderRadius: BorderRadius.circular(8),
                                  
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                        
                                    Icon(Icons.visibility, color: Color((0xFF0010a2)), size: 10,),
                                    Text("1,2rb", style: TextStyle(fontSize: 10, color: Color(0xFF0010a2), ),
                                     textAlign: TextAlign.center,)
                                  ],),
                                ),
                              ),
                            ],
                          ),
                          
                          ],
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                                width: width(context) * 0.8,
                                height: height(context) * 0.05,
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.only(left: 8),  
                                decoration: const BoxDecoration(
                                  color: Color(0xffe9f9ff), 
                      
                                ),
                                child: const Text("Cara Melakukan Budidaya Burung Walet", style: TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.w400),),
                              
                              
                              ),
                          ],
                        )
                        
                        
                        
                      ],
                    ),
                    
                 ),
               ),
                  ],
                ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
              icon: CustomBottomNavigationItem(
                icon: Icons.home,
                label: 'Beranda',
                currentIndex: _currentIndex,
                itemIndex: 0,
                onTap: () {
                  Navigator.pushReplacementNamed(context, '/home-page');
                  setState(() {
                    _currentIndex = 0;
                  });
                },
              ),
              label: ''),
          BottomNavigationBarItem(
              icon: CustomBottomNavigationItem(
                icon: Icons.store,
                label: 'Toko',
                currentIndex: _currentIndex,
                itemIndex: 1,
                onTap: () {
                  Navigator.pushReplacementNamed(context, '/store-page');
                  setState(() {
                    _currentIndex = 1;
                  });
                },
              ),
              label: ''),
          BottomNavigationBarItem(
              icon: CustomBottomNavigationItem(
                icon: Icons.chat_sharp,
                label: 'Komunitas',
                currentIndex: _currentIndex,
                itemIndex: 2,
                onTap: () {
                  Navigator.pushReplacementNamed(context, '/community-page');
                  setState(() {
                    _currentIndex = 2;
                  });
                },
              ),
              label: ''),
          BottomNavigationBarItem(
              icon: CustomBottomNavigationItem(
                icon: Icons.dataset_sharp,
                label: 'kontrol',
                currentIndex: _currentIndex,
                itemIndex: 3,
                onTap: () {
                  Navigator.pushReplacementNamed(context, '/control-page');
                  setState(() {
                    _currentIndex = 3;
                  });
                },
              ),
              label: ''),
          BottomNavigationBarItem(
              icon: CustomBottomNavigationItem(
                icon: Icons.person,
                label: 'Profil',
                currentIndex: _currentIndex,
                itemIndex: 4,
                onTap: () {
                  Navigator.pushReplacementNamed(context, '/profile-page');
                  setState(() {
                    _currentIndex = 4;
                  });
                },
              ),
              label: ''),
        ],
      ),
    );
  }
}
