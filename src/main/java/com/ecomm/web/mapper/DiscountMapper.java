package com.ecomm.web.mapper;

import com.ecomm.web.dto.product.DiscountDto;
import com.ecomm.web.model.product.Discount;

import static com.ecomm.web.mapper.StoreMapper.mapToStoreDto;
public class DiscountMapper {
    public static DiscountDto mapToDiscountDto(Discount discount) {
        if(discount == null) return null;
        return DiscountDto.builder()
                            .name(discount.getName())
                            .desc(discount.getDesc())
                            .disc(discount.getDisc())
                            .startDate(discount.getStartDate())
                            .endDate(discount.getEndDate())
                            //.active(discount.getActive())
                            .disc(discount.getDisc())
                            .store(mapToStoreDto(discount.getStore()))
                            .build();
    }
    public static Discount mapToDiscount(DiscountDto discountDto) {
        return Discount.builder()
                        .name(discountDto.getName())
                        .desc(discountDto.getDesc())
                        .disc(discountDto.getDisc())
                        .startDate(discountDto.getStartDate())
                        .endDate(discountDto.getEndDate())
                        .build();
    }
}
