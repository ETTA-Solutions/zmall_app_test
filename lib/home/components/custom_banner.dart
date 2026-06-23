import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:zmall/utils/constants.dart';
import 'package:zmall/utils/size_config.dart';

class CustomBanner extends StatelessWidget {
  const CustomBanner({
    super.key,
    required this.imageUrl,
    required this.press,
    required this.subtitle,
    required this.title,
    this.isNetworkImage = false,
  });

  final String imageUrl;
  final String title;
  final String subtitle;
  final bool isNetworkImage;
  final GestureTapCallback press;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: press,
      child: Container(
        width: double.infinity,
        height: getProportionateScreenHeight(kDefaultPadding * 7.5),
        // margin: EdgeInsets.symmetric(
        //   horizontal: getProportionateScreenWidth(kDefaultPadding),
        // ),
        // padding:EdgeInsets.all(getProportionateScreenWidth(kDefaultPadding / 2)),
        decoration: BoxDecoration(
          color: kPrimaryColor,
          border: Border.all(
            color: kWhiteColor,
            // kGreyColor.withValues(alpha: 0.1)
          ),
          borderRadius: BorderRadius.circular(
            getProportionateScreenWidth(kDefaultPadding),
          ),
          // boxShadow: [boxShadow],
          // image: DecorationImage(
          //   image: isNetworkImage
          //       ? NetworkImage(imageUrl) as ImageProvider<Object>
          //       : AssetImage(imageUrl),
          //   fit: BoxFit.fill,
          // ),
        ),
        child: !isNetworkImage
            ? Container(
                width: double.infinity,
                height: getProportionateScreenHeight(kDefaultPadding * 8),
                decoration: BoxDecoration(
                  image: DecorationImage(
                    fit: BoxFit.fill,
                    image: AssetImage(imageUrl),
                  ),
                  borderRadius: BorderRadius.circular(
                    getProportionateScreenWidth(kDefaultPadding),
                  ),
                ),
              )
            : CachedNetworkImage(
                imageUrl: imageUrl,
                imageBuilder: (context, imageProvider) => Container(
                  width: double.infinity,
                  height: getProportionateScreenHeight(kDefaultPadding * 8),
                  decoration: BoxDecoration(
                    color: kPrimaryColor,
                    borderRadius: BorderRadius.circular(
                      getProportionateScreenHeight(kDefaultPadding),
                    ),
                    image: DecorationImage(
                      fit: BoxFit.fill,
                      image: imageProvider,
                    ),
                  ),
                ),
                placeholder: (context, url) => Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(kSecondaryColor),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  width: double.infinity,
                  height: getProportionateScreenHeight(kDefaultPadding * 8),
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      fit: BoxFit.fill,
                      image: AssetImage(imageUrl),
                    ),
                  ),
                ),
              ),
        // child: Column(
        //   mainAxisAlignment: MainAxisAlignment.end,
        //   crossAxisAlignment: CrossAxisAlignment.start,
        //   children: [
        //     Container(
        //       padding: EdgeInsets.all(kDefaultPadding / 2),
        //       decoration: BoxDecoration(
        //         color: kPrimaryColor.withValues(alpha: 0.7),
        //         borderRadius: BorderRadius.circular(kDefaultPadding),
        //       ),
        //       child: Text.rich(
        //         TextSpan(
        //           text: title,
        //           style: TextStyle(
        //             color: kSecondaryColor,
        //           ),
        //           children: [
        //             TextSpan(
        //               text: subtitle,
        //               style: TextStyle(
        //                 color: kSecondaryColor,
        //                 fontWeight: FontWeight.bold,
        //                 fontSize:
        //                     getProportionateScreenWidth(kDefaultPadding + 4),
        //               ),
        //             ),
        //           ],
        //         ),
        //       ),
        //     ),
        //   ],
        // ),
      ),
    );
  }
}
//overlay Title UI
// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:flutter/material.dart';
// import 'package:zmall/utils/constants.dart';
// import 'package:zmall/utils/size_config.dart';

// class CustomBanner extends StatelessWidget {
//   const CustomBanner({
//     super.key,
//     required this.imageUrl,
//     required this.press,
//     required this.subtitle,
//     required this.title,
//     this.isNetworkImage = false,
//   });

//   final String imageUrl;
//   final String title;
//   final String subtitle;
//   final bool isNetworkImage;
//   final GestureTapCallback press;

//   @override
//   Widget build(BuildContext context) {
//     return InkWell(
//       onTap: press,
//       child: Container(
//         width: double.infinity,
//         height: getProportionateScreenHeight(kDefaultPadding * 7.5),
//         // margin: EdgeInsets.symmetric(
//         //   horizontal: getProportionateScreenWidth(kDefaultPadding),
//         child: Stack(
//           fit: StackFit.expand,
//           children: [
//             imageUrl.isEmpty
//                 ? Container(
//                     decoration: BoxDecoration(
//                       gradient: LinearGradient(
//                         begin: Alignment.topLeft,
//                         end: Alignment.bottomRight,
//                         colors: [
//                           kPrimaryColor,
//                           kSecondaryColor.withValues(alpha: 0.85),
//                         ],
//                       ),
//                       borderRadius: BorderRadius.circular(
//                         getProportionateScreenWidth(kDefaultPadding),
//                       ),
//                     ),
//                     child: Center(
//                       child: Icon(
//                         Icons.lunch_dining,
//                         color: kWhiteColor.withValues(alpha: 0.9),
//                         size: getProportionateScreenHeight(
//                           kDefaultPadding * 2.5,
//                         ),
//                       ),
//                     ),
//                   )
//                 : !isNetworkImage
//                 ? Container(
//                     decoration: BoxDecoration(
//                       image: DecorationImage(
//                         fit: BoxFit.fill,
//                         image: AssetImage(imageUrl),
//                       ),
//                       borderRadius: BorderRadius.circular(
//                         getProportionateScreenWidth(kDefaultPadding),
//                       ),
//                     ),
//                   )
//                 : CachedNetworkImage(
//                     imageUrl: imageUrl,
//                     imageBuilder: (context, imageProvider) => Container(
//                       decoration: BoxDecoration(
//                         color: kPrimaryColor,
//                         borderRadius: BorderRadius.circular(
//                           getProportionateScreenHeight(kDefaultPadding),
//                         ),
//                         image: DecorationImage(
//                           fit: BoxFit.fill,
//                           image: imageProvider,
//                         ),
//                       ),
//                     ),
//                     placeholder: (context, url) => Center(
//                       child: CircularProgressIndicator(
//                         valueColor: AlwaysStoppedAnimation<Color>(
//                           kSecondaryColor,
//                         ),
//                       ),
//                     ),
//                     errorWidget: (context, url, error) => Container(
//                       decoration: BoxDecoration(
//                         gradient: LinearGradient(
//                           begin: Alignment.topLeft,
//                           end: Alignment.bottomRight,
//                           colors: [
//                             kPrimaryColor,
//                             kSecondaryColor.withValues(alpha: 0.85),
//                           ],
//                         ),
//                         borderRadius: BorderRadius.circular(
//                           getProportionateScreenWidth(kDefaultPadding),
//                         ),
//                       ),
//                       child: Center(
//                         child: Icon(
//                           Icons.lunch_dining,
//                           color: kWhiteColor.withValues(alpha: 0.9),
//                           size: getProportionateScreenHeight(
//                             kDefaultPadding * 2.5,
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//             Container(
//               decoration: BoxDecoration(
//                 borderRadius: BorderRadius.circular(
//                   getProportionateScreenWidth(kDefaultPadding),
//                 ),
//                 gradient: LinearGradient(
//                   begin: Alignment.topCenter,
//                   end: Alignment.bottomCenter,
//                   colors: [
//                     Colors.transparent,
//                     Colors.black.withValues(alpha: 0.45),
//                   ],
//                 ),
//               ),
//             ),
//             if (title.isNotEmpty || subtitle.isNotEmpty)
//               Positioned(
//                 left: getProportionateScreenWidth(kDefaultPadding / 2),
//                 right: getProportionateScreenWidth(kDefaultPadding / 2),
//                 bottom: getProportionateScreenHeight(kDefaultPadding / 2),
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       title,
//                       maxLines: 2,
//                       overflow: TextOverflow.ellipsis,
//                       style: Theme.of(context).textTheme.titleMedium?.copyWith(
//                         color: kWhiteColor,
//                         fontWeight: FontWeight.bold,
//                         shadows: const [
//                           Shadow(
//                             blurRadius: 6,
//                             color: Colors.black54,
//                             offset: Offset(0, 1),
//                           ),
//                         ],
//                       ),
//                     ),
//                     if (subtitle.isNotEmpty)
//                       Text(
//                         subtitle,
//                         maxLines: 2,
//                         overflow: TextOverflow.ellipsis,
//                         style: Theme.of(context).textTheme.bodySmall?.copyWith(
//                           color: kWhiteColor.withValues(alpha: 0.9),
//                           fontWeight: FontWeight.w600,
//                           shadows: const [
//                             Shadow(
//                               blurRadius: 4,
//                               color: Colors.black45,
//                               offset: Offset(0, 1),
//                             ),
//                           ],
//                         ),
//                       ),
//                   ],
//                 ),
//               ),
//           ],
//         ),
//         //           style: TextStyle(
//         //             color: kSecondaryColor,
//         //           ),
//         //           children: [
//         //             TextSpan(
//         //               text: subtitle,
//         //               style: TextStyle(
//         //                 color: kSecondaryColor,
//         //                 fontWeight: FontWeight.bold,
//         //                 fontSize:
//         //                     getProportionateScreenWidth(kDefaultPadding + 4),
//         //               ),
//         //             ),
//         //           ],
//         //         ),
//         //       ),
//         //     ),
//         //   ],
//         // ),
//       ),
//     );
//   }
// }
