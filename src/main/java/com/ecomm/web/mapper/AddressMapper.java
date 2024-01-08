package com.ecomm.web.mapper;

import com.ecomm.web.dto.user.AddressDto;
import com.ecomm.web.model.user.Address;

public class AddressMapper {
    public static AddressDto mapToAddressDto(Address address) {
        return AddressDto.builder()
                    .address(address.getAddress())
                    .city(address.getCity())
                    .postalCode(address.getPostalCode())
                    .country(address.getCountry())
                    .build();
    }
    public static Address mapToAddress(AddressDto address) {
        return Address.builder()
                    .address(address.getAddress())
                    .city(address.getCity())
                    .postalCode(address.getPostalCode())
                    .country(address.getCountry())
                    .build();
    }
}
